import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/services/resources_service.dart';
import '../widgets/teacher_stat_card.dart';
import '../attendance/attendance_screen.dart';
import '../../video_room/video_room_screen.dart';

class TeacherHomeTab extends StatefulWidget {
  const TeacherHomeTab({super.key});

  @override
  State<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends State<TeacherHomeTab> {
  final supabase = Supabase.instance.client;
  final _resourcesService = ResourcesService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _todaySessionsRaw = [];
  List<SessionModel> _todaySessions = [];
  int _totalStudents = 0;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final teacherId = supabase.auth.currentUser!.id;
      final today = DateTime.now().toIso8601String().split('T')[0];

      final sessionsResponse = await supabase
          .from('sessions')
          .select('*, profiles:teacher_id(full_name), rooms(is_active)')
          .eq('teacher_id', teacherId)
          .gte('start_time', '${today}T00:00:00')
          .lte('start_time', '${today}T23:59:59')
          .order('start_time', ascending: true);

      _todaySessionsRaw = List<Map<String, dynamic>>.from(sessionsResponse);
      
      if (_todaySessionsRaw.isNotEmpty) {
        final List<String> sessionIds = _todaySessionsRaw.map((s) => s['id'].toString()).toList();
        final enrollmentsRes = await supabase
            .from('enrollments')
            .select()
            .inFilter('session_id', sessionIds)
            .count(CountOption.exact);
        
        setState(() {
          _totalStudents = enrollmentsRes.count;
        });
      }

      setState(() {
        _todaySessions = _todaySessionsRaw.map((data) {
          final rooms = data['rooms'] as List?;
          final bool hasActiveRoom = rooms != null && rooms.any((r) => r['is_active'] == true);
          final session = SessionModel.fromMap(data);
          return SessionModel(
            id: session.id,
            subjectName: session.subjectName,
            teacherName: session.teacherName,
            startTime: session.startTime,
            endTime: session.endTime,
            isLive: hasActiveRoom,
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading teacher data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStartSession(SessionModel session) async {
    setState(() => _isLoading = true);
    try {
      await supabase.rpc('start_teacher_session', params: {
        'p_session_id': session.id,
      });

      if (!mounted) return;
      await _loadTeacherData();
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoRoomScreen(
            title: "بث مباشر: ${session.subjectName}",
            roomName: "room_${session.id}",
            userName: "Teacher_${session.teacherName}",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في بدء الحصة: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEndSession(String sessionId) async {
    setState(() => _isLoading = true);
    try {
      await supabase.from('rooms').update({'is_active': false}).eq('session_id', sessionId);
      await _loadTeacherData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إنهاء الحصة بنجاح")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في إنهاء الحصة: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUploadDialog(String sessionId) async {
    final titleController = TextEditingController();
    PlatformFile? pickedFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("رفع ملف جديد"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "عنوان الملف"),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
                  );
                  if (result != null) {
                    setDialogState(() => pickedFile = result.files.first);
                  }
                },
                icon: const Icon(IconlyLight.upload),
                label: Text(pickedFile?.name ?? "اختر ملفاً"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: pickedFile == null ? null : () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("جاري الرفع...")));
                final success = await _resourcesService.uploadResource(
                  sessionId: sessionId,
                  title: titleController.text,
                  pickerFile: pickedFile!,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? "تم الرفع بنجاح" : "فشل الرفع")),
                  );
                }
              },
              child: const Text("رفع الآن"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = _todaySessions.isNotEmpty ? _todaySessions.first : null;
    final currentSessionRaw = _todaySessionsRaw.isNotEmpty ? _todaySessionsRaw.first : null;
    final teacherName = supabase.auth.currentUser?.userMetadata?['full_name'] ?? "المدرس";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text("EduConnect Teacher", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => supabase.auth.signOut().then((_) => Navigator.pushReplacementNamed(context, '/login')),
            icon: const Icon(IconlyLight.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading && _todaySessions.isEmpty
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _loadTeacherData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(teacherName),
                    const SizedBox(height: 24),
                    _buildStatsRow(),
                    const SizedBox(height: 32),
                    const Text("الحصة القادمة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (currentSession != null)
                      _buildCurrentSessionCard(currentSession, currentSessionRaw?['class_code'])
                    else
                      _buildEmptyState(),
                    const SizedBox(height: 32),
                    const Text("إجراءات سريعة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildQuickActions(currentSession),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(String name) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("أهلاً بك، 👋", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
      Text("أ. $name", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildStatsRow() {
    return Row(children: [
      Expanded(child: TeacherStatCard(title: "إجمالي الطلاب", value: _totalStudents.toString(), icon: IconlyLight.user_1, color: Colors.blue)),
      const SizedBox(width: 16),
      Expanded(child: TeacherStatCard(title: "حصص اليوم", value: _todaySessions.length.toString(), icon: IconlyLight.video, color: Colors.orange)),
    ]);
  }

  Widget _buildCurrentSessionCard(SessionModel session, String? classCode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: session.isLive 
              ? [Colors.red.shade700, Colors.red.shade500] 
              : [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: (session.isLive ? Colors.red : Colors.blue).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(children: [
            const Icon(IconlyLight.video, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.subjectName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text("${DateFormat('hh:mm a').format(session.startTime)} - ${DateFormat('hh:mm a').format(session.endTime)}", style: TextStyle(color: Colors.white.withOpacity(0.8))),
            ])),
          ]),
          if (classCode != null && classCode.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildCodePanel(classCode),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleStartSession(session),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: session.isLive ? Colors.red.shade700 : Colors.blue.shade700,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(session.isLive ? "العودة للبث" : "بدء البث المباشر", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              if (session.isLive) ...[
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: () => _showEndDialog(session.id),
                  icon: const Icon(IconlyBold.close_square),
                  style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white, minimumSize: const Size(56, 56)),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCodePanel(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("كود انضمام الطلاب", style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text(code, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ]),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم نسخ الكود!")));
            },
            icon: const Icon(Icons.copy_all_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(SessionModel? currentSession) {
    return Column(
      children: [
        _buildActionCard(
          icon: IconlyLight.user_1,
          color: Colors.orange,
          title: "تسجيل الحضور والغياب",
          onTap: () {
            if (currentSession != null) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen(sessionId: currentSession.id, subjectName: currentSession.subjectName)));
            }
          },
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          icon: IconlyLight.folder,
          color: Colors.blue,
          title: "إدارة المصادر والملفات",
          onTap: () {
            if (currentSession != null) {
              _showUploadDialog(currentSession.id);
            }
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({required IconData icon, required Color color, required String title, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)]),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showEndDialog(String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إنهاء الحصة"),
        content: const Text("هل أنت متأكد من إنهاء البث المباشر وإغلاق الغرفة؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(onPressed: () { Navigator.pop(context); _handleEndSession(sessionId); }, child: const Text("إنهاء الآن", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100, child: Container());
  }

  Widget _buildEmptyState() {
    return const Center(child: Text("لا توجد حصص مجدولة"));
  }

  Widget _buildAnimatedCard({required Widget child}) {
    return child;
  }
}
