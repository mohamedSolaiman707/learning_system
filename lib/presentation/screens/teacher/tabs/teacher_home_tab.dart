import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/utils/responsive.dart';
import '../assignments/teacher_assignments_screen.dart';
import '../attendance/attendance_screen.dart';
import '../resources/teacher_resources_screen.dart';
import '../../video_room/video_room_screen.dart';
import '../widgets/teacher_stat_card.dart';

class TeacherHomeTab extends StatefulWidget {
  const TeacherHomeTab({super.key});

  @override
  State<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends State<TeacherHomeTab> {
  bool _isLoading = true;
  List<SessionModel> _sessions = [];
  SessionModel? _nextSession;
  int _totalStudents = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      
      if (auth.user != null) {
        final results = await Future.wait([
          db.getTeacherSessions(auth.user!.id),
          db.getTeacherStats(auth.user!.id),
        ]);

        if (mounted) {
          setState(() {
            _sessions = (results[0] as List).map((e) => SessionModel.fromMap(e)).toList();
            _totalStudents = (results[1] as Map<String, dynamic>)['totalStudents'] ?? 0;

            final now = DateTime.now();
            final activeSessions = _sessions.where((s) => s.endTime.isAfter(now)).toList();

            if (activeSessions.isNotEmpty) {
              _nextSession = activeSessions.first;
            } else {
              _nextSession = null;
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleQuickAction(String type) {
    if (_sessions.isEmpty) {
      _showNoSessionAlert();
      return;
    }
    if (_sessions.length == 1) {
      _navigateToActionScreen(type, _sessions.first);
    } else {
      _showSessionPicker(type);
    }
  }

  void _showNoSessionAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("لا توجد حصص مسجلة لديك حالياً"))
    );
  }

  void _showSessionPicker(String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type == 'attendance' ? "اختر حصة للتحضير" : 
              type == 'assignment' ? "اختر حصة للواجبات" : "اختر حصة للمكتبة", 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final s = _sessions[index];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(IconlyLight.video, color: Colors.blue)),
                    title: Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(intl.DateFormat('hh:mm a').format(s.startTime)),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToActionScreen(type, s);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToActionScreen(String type, SessionModel session) {
    if (type == 'attendance') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen(sessionId: session.id, subjectName: session.subjectName)));
    } else if (type == 'assignment') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => TeacherAssignmentsScreen(sessionId: session.id, subjectName: session.subjectName)));
    } else if (type == 'resources') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => TeacherResourcesScreen(sessionId: session.id, subjectName: session.subjectName)));
    }
  }

  void _showAddSessionDialog() {
    final nameController = TextEditingController();
    DateTime startDate = DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();
    int selectedDurationMinutes = 60;
    bool isRecordingEnabled = true;

    final List<Map<String, dynamic>> durations = [
      {'label': '30 دقيقة', 'value': 30},
      {'label': '45 دقيقة', 'value': 45},
      {'label': 'ساعة واحدة', 'value': 60},
      {'label': 'ساعة ونصف', 'value': 90},
      {'label': 'ساعتين', 'value': 120},
      {'label': '3 ساعات', 'value': 180},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("جدولة حصة جديدة", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "اسم المادة/الحصة",
                    prefixIcon: const Icon(IconlyLight.edit),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("توقيت البدء", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildDateTimePicker(
                  label: "تاريخ ووقت البدء",
                  date: startDate,
                  time: startTime,
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                    if (d != null) {
                      final t = await showTimePicker(context: context, initialTime: startTime);
                      if (t != null) setDialogState(() { startDate = d; startTime = t; });
                    }
                  },
                ),
                const SizedBox(height: 20),
                const Text("مدة الحصة", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedDurationMinutes,
                      isExpanded: true,
                      items: durations.map((d) => DropdownMenuItem<int>(
                        value: d['value'],
                        child: Text(d['label']),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedDurationMinutes = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text("تسجيل الحصة تلقائياً", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text("سيتم حفظ الفيديو في مكتبة الحصص", style: TextStyle(fontSize: 11)),
                  value: isRecordingEnabled,
                  onChanged: (val) => setDialogState(() => isRecordingEnabled = val),
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.red,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                final start = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute);
                final end = start.add(Duration(minutes: selectedDurationMinutes));
                
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final db = Provider.of<DatabaseService>(context, listen: false);
                
                await db.saveSession({
                  'subject_name': nameController.text,
                  'teacher_id': auth.user!.id,
                  'start_time': start.toIso8601String(),
                  'end_time': end.toIso8601String(),
                  'class_code': (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0'),
                  'status': 'waiting',
                  'is_recording_enabled': isRecordingEnabled,
                });
                if (mounted) { Navigator.pop(context); _loadData(); }
              },
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text("حفظ الحصة"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({required String label, required DateTime date, required TimeOfDay time, required VoidCallback onTap}) {
    final formatted = "${intl.DateFormat('yyyy-MM-dd').format(date)} ${time.format(context)}";
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
        child: Row(
          children: [
            const Icon(IconlyLight.calendar, size: 20, color: Colors.blue),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _quickStartLive(String teacherName) async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      
      final sessionData = await db.saveSession({
        'subject_name': "بث مباشر سريع - $teacherName",
        'teacher_id': auth.user!.id,
        'start_time': DateTime.now().toIso8601String(),
        'end_time': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        'class_code': (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0'),
        'status': 'active',
        'is_recording_enabled': true,
      });

      if (sessionData != null && mounted) {
        final sessionModel = SessionModel.fromMap(sessionData);
        await _startLive(sessionModel, teacherName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل بدء البث السريع")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startLive(SessionModel session, String teacherName) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.user?.id ?? "";
      final db = Provider.of<DatabaseService>(context, listen: false);
      
      await db.toggleRoomStatus(session.id, true);
      if (!mounted) return;
      
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => VideoRoomScreen(
          title: session.subjectName, 
          roomName: "room_${session.id}", 
          userName: "أ. $teacherName",
          userId: userId, 
          isTeacher: true,
          sessionId: session.id,
        )
      )).then((_) => _showEndLiveDialog(session.id));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل بدء البث المباشر")));
    }
  }

  void _showEndLiveDialog(String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إنهاء البث"),
        content: const Text("هل انتهت الحصة وتريد إغلاق البث للطلاب؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("لا، سأعود")),
          ElevatedButton(
            onPressed: () async {
              final db = Provider.of<DatabaseService>(context, listen: false);
              await db.toggleRoomStatus(sessionId, false);
              if (mounted) { Navigator.pop(context); _loadData(); }
            },
            child: const Text("نعم، إنهاء الحصة"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final name = authProvider.profile?['full_name'] ?? "المدرس";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(name),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(Responsive.isMobile(context) ? 16 : 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeHeader(name),
                          const SizedBox(height: 24),
                          _buildStatsSection(),
                          const SizedBox(height: 32),
                          Responsive(
                            mobile: Column(children: [_buildCurrentSessionSection(name), const SizedBox(height: 32), _buildQuickActions()]),
                            desktop: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(flex: 3, child: _buildCurrentSessionSection(name)),
                              const SizedBox(width: 30),
                              Expanded(flex: 2, child: _buildQuickActions()),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSliverAppBar(String name) {
    return SliverAppBar(
      expandedHeight: 100, floating: true, pinned: true,
      backgroundColor: Colors.white, elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text("لوحة المدرس", style: TextStyle(color: Colors.black.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
      ),
      actions: [
        IconButton(
          onPressed: _showAddSessionDialog, 
          icon: const Icon(IconlyLight.plus, color: Colors.blue),
          tooltip: "إضافة حصة مجدولة",
        ),
        IconButton(
          onPressed: () => _quickStartLive(name), 
          icon: const Icon(Icons.bolt, color: Colors.amber, size: 28),
          tooltip: "بث مباشر سريع",
        ),
        IconButton(onPressed: () {}, icon: const Badge(child: Icon(IconlyLight.notification))), 
        const SizedBox(width: 15)
      ],
    );
  }

  Widget _buildWelcomeHeader(String name) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("أهلاً بك، 👋", style: TextStyle(fontSize: 16, color: Colors.grey)),
      Text("أ. $name", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(child: TeacherStatCard(title: "طلابك", value: _totalStudents.toString(), icon: IconlyLight.user_1, color: Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: TeacherStatCard(title: "حصص اليوم", value: _sessions.length.toString(), icon: IconlyLight.video, color: Colors.orange)),
        if (Responsive.isDesktop(context)) ...[
          const SizedBox(width: 16),
          const Expanded(child: TeacherStatCard(title: "التقييم", value: "5.0", icon: IconlyLight.star, color: Colors.amber)),
        ]
      ],
    );
  }

  Widget _buildCurrentSessionSection(String teacherName) {
    if (_nextSession == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(IconlyLight.calendar, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("لا توجد حصص قادمة حالياً", style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.bold)),
            const Text("سيتم إعلامك فور إضافة حصص جديدة", style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }
    final now = DateTime.now();
    final isUpcoming = _nextSession!.startTime.isAfter(now);
    
    final startTimeStr = intl.DateFormat('hh:mm a').format(_nextSession!.startTime);
    // جعل الرابط ديناميكياً بناءً على الـ Domain الحالي
    final String liveLink = "${Uri.base.origin}/#/live?sessionId=${_nextSession!.id}";

    final db = Provider.of<DatabaseService>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isUpcoming ? "الحصة القادمة" : "بث مباشر الآن 🔴",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isUpcoming ? Colors.black : Colors.red)),
            if (_nextSession!.isWaiting)
              StreamBuilder<int>(
                stream: db.watchWaitingCount(_nextSession!.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text("${snapshot.data} طالب في الانتظار", style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: isUpcoming
                ? LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade400])
                : const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFFF5252)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: (isUpcoming ? Colors.blue : Colors.red).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                    child: Icon(isUpcoming ? IconlyLight.calendar : IconlyLight.video, color: Colors.white, size: 30)
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_nextSession!.subjectName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("تبدأ في $startTimeStr وتستمر حتى ${intl.DateFormat('hh:mm a').format(_nextSession!.endTime)}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildCopyBadge(
                          label: "كود: ${_nextSession!.classCode}", 
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _nextSession!.classCode));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم نسخ كود الحصة")));
                          }
                        ),
                        const SizedBox(width: 8),
                        _buildCopyBadge(
                          label: "نسخ الرابط 🔗", 
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: liveLink));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم نسخ رابط الحصة المباشر")));
                          }
                        ),
                      ],
                    ),
                  ])),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _startLive(_nextSession!, teacherName),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: isUpcoming ? Colors.blue.shade700 : Colors.red,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: Text(
                  _nextSession!.isActive ? "دخول البث المباشر" : "بدء البث المباشر", 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCopyBadge({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("إجراءات سريعة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _buildActionCard("التحضير", IconlyLight.user, Colors.blue, 'attendance'),
            _buildActionCard("الواجبات", IconlyLight.document, Colors.orange, 'assignment'),
            _buildActionCard("المكتبة", IconlyLight.folder, Colors.purple, 'resources'),
            _buildActionCard("التقارير", IconlyLight.chart, Colors.green, 'reports'),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, String type) {
    return InkWell(
      onTap: () => _handleQuickAction(type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
