import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
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
  List<Map<String, dynamic>> _allSessionsRaw = [];
  List<SessionModel> _sessions = [];
  int _totalStudents = 0;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _filterAndRefreshSessions();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTeacherData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final teacherId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('sessions')
          .select('*, profiles:teacher_id(full_name), rooms(is_active)')
          .eq('teacher_id', teacherId)
          .gte('end_time', DateTime.now().toUtc().toIso8601String())
          .order('start_time', ascending: true);

      _allSessionsRaw = List<Map<String, dynamic>>.from(response);
      _filterAndRefreshSessions();
      
      if (_allSessionsRaw.isNotEmpty) {
        final List<String> sessionIds = _allSessionsRaw.map((s) => s['id'].toString()).toList();
        final enrollmentsRes = await supabase
            .from('enrollments')
            .select()
            .inFilter('session_id', sessionIds)
            .count(CountOption.exact);
        
        setState(() => _totalStudents = enrollmentsRes.count);
      }
    } catch (e) {
      debugPrint("Error loading teacher data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterAndRefreshSessions() {
    final now = DateTime.now();
    setState(() {
      _sessions = _allSessionsRaw.map((data) {
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
      }).where((s) => s.endTime.isAfter(now)).toList();
    });
  }

  Future<void> _handleStartSession(SessionModel session) async {
    setState(() => _isLoading = true);
    try {
      await supabase.rpc('start_teacher_session', params: {'p_session_id': session.id});
      await _loadTeacherData();
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => VideoRoomScreen(title: "بث مباشر: ${session.subjectName}", roomName: "room_${session.id}", userName: "Teacher_${session.teacherName}")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إنهاء الحصة بنجاح"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUploadDialog(String sessionId) async {
    final titleController = TextEditingController();
    PlatformFile? pickedFile;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("رفع ملف جديد"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: "عنوان الملف", prefixIcon: Icon(IconlyLight.document))),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'png'], withData: true);
                  if (result != null) setDialogState(() => pickedFile = result.files.first);
                },
                icon: const Icon(IconlyLight.upload),
                label: Expanded(child: Text(pickedFile?.name ?? "اختر ملفاً", overflow: TextOverflow.ellipsis)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: pickedFile == null ? null : () async {
                Navigator.pop(context);
                scaffoldMessenger.showSnackBar(const SnackBar(content: Text("جاري الرفع...")));
                final error = await _resourcesService.uploadResource(sessionId: sessionId, title: titleController.text, pickerFile: pickedFile!);
                if (error == null) {
                  scaffoldMessenger.showSnackBar(const SnackBar(content: Text("تم الرفع بنجاح!"), backgroundColor: Colors.green));
                } else {
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text("فشل: $error"), backgroundColor: Colors.red));
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
    final currentSession = _sessions.isNotEmpty ? _sessions.first : null;
    final String? currentClassCode = currentSession == null ? null : _allSessionsRaw.firstWhere((s) => s['id'] == currentSession.id, orElse: () => {})['class_code'];
    final teacherName = supabase.auth.currentUser?.userMetadata?['full_name'] ?? "المدرس";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text("لوحة المدرس"), actions: [IconButton(onPressed: () => supabase.auth.signOut().then((_) => Navigator.pushReplacementNamed(context, '/login')), icon: const Icon(IconlyLight.logout)), const SizedBox(width: 8)]),
      body: _isLoading && _sessions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeacherData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(teacherName),
                    const SizedBox(height: 24),
                    _buildStatsRow(),
                    const SizedBox(height: 32),
                    Text(currentSession != null && currentSession.startTime.isBefore(DateTime.now()) ? "الحصة الحالية" : "الحصة القادمة", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (currentSession != null) _buildCurrentSessionCard(currentSession, currentClassCode) else _buildEmptyState(),
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

  Widget _buildHeader(String name) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("أهلاً بك، 👋", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)), Text("أ. $name", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))]);
  Widget _buildStatsRow() => Row(children: [Expanded(child: TeacherStatCard(title: "إجمالي الطلاب", value: _totalStudents.toString(), icon: IconlyLight.user_1, color: Colors.blue)), const SizedBox(width: 16), Expanded(child: TeacherStatCard(title: "حصص اليوم", value: _sessions.length.toString(), icon: IconlyLight.video, color: Colors.orange))]);
  
  Widget _buildCurrentSessionCard(SessionModel session, String? classCode) {
    final timeRange = "${intl.DateFormat('hh:mm a').format(session.startTime)} - ${intl.DateFormat('hh:mm a').format(session.endTime)}";
    return Container(
      padding: const EdgeInsets.all(24), 
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: session.isLive ? [Colors.red.shade700, Colors.red.shade500] : [Colors.blue.shade700, Colors.blue.shade500]), 
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: (session.isLive ? Colors.red : Colors.blue).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ), 
      child: Column(children: [
        Row(children: [const Icon(IconlyLight.video, color: Colors.white, size: 28), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(session.subjectName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), Directionality(textDirection: TextDirection.ltr, child: Text(timeRange, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)))]))]), 
        if (classCode != null) ...[const SizedBox(height: 20), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("كود الحصة: $classCode", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), IconButton(onPressed: () { Clipboard.setData(ClipboardData(text: classCode)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم نسخ الكود"))); }, icon: const Icon(Icons.copy, color: Colors.white, size: 18))]))], 
        const SizedBox(height: 24), 
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: () => _handleStartSession(session), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: session.isLive ? Colors.red.shade700 : Colors.blue.shade700, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: Text(session.isLive ? "العودة للبث" : "بدء البث المباشر"))),
          if (session.isLive) ...[const SizedBox(width: 12), IconButton(onPressed: () => _showEndDialog(session.id), icon: const Icon(IconlyBold.close_square, color: Colors.white), style: IconButton.styleFrom(backgroundColor: Colors.white24, minimumSize: const Size(56, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))]
        ]),
      ]));
  }

  Widget _buildQuickActions(SessionModel? currentSession) => Column(children: [
    _buildActionCard(icon: IconlyLight.user_1, color: Colors.orange, title: "تسجيل الحضور", onTap: () {
      if (currentSession != null) Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen(sessionId: currentSession.id, subjectName: currentSession.subjectName)));
    }), 
    const SizedBox(height: 12), 
    _buildActionCard(icon: IconlyLight.folder, color: Colors.blue, title: "إدارة المصادر", onTap: () => currentSession != null ? _showUploadDialog(currentSession.id) : null)
  ]);

  Widget _buildActionCard({required IconData icon, required Color color, required String title, required VoidCallback onTap}) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)]), child: ListTile(leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: onTap));
  
  void _showEndDialog(String sessionId) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("إنهاء الحصة"), content: const Text("هل أنت متأكد من إنهاء البث وإغلاق الغرفة؟"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")), TextButton(onPressed: () { Navigator.pop(context); _handleEndSession(sessionId); }, child: const Text("إنهاء", style: TextStyle(color: Colors.red)))]));
  }

  Widget _buildEmptyState() => Container(width: double.infinity, padding: const EdgeInsets.all(40), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)), child: const Column(children: [Icon(IconlyLight.calendar, size: 64, color: Colors.grey), SizedBox(height: 16), Text("لا توجد حصص مجدولة", style: TextStyle(color: Colors.grey))]));
}
