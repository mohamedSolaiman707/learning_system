import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/utils/responsive.dart';
import '../attendance/attendance_screen.dart';
import '../reports/teacher_reports_screen.dart';
import '../../video_room/video_room_screen.dart';
import '../../video_room/video_room_controller.dart';
import '../widgets/teacher_stat_card.dart';

class TeacherHomeTab extends StatefulWidget {
  const TeacherHomeTab({super.key});

  @override
  State<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends State<TeacherHomeTab> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<SessionModel> _sessions = [];
  SessionModel? _activeSession;
  SessionModel? _nextSession;
  int _totalStudents = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
            
            _activeSession = _sessions.cast<SessionModel?>().firstWhere(
              (s) => s!.status == 'active' || (s.startTime.isBefore(now) && s.endTime.isAfter(now)),
              orElse: () => null,
            );

            _nextSession = _sessions.cast<SessionModel?>().firstWhere(
              (s) => s!.startTime.isAfter(now) && s.id != _activeSession?.id,
              orElse: () => null,
            );

            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createInstantLive() async {
    HapticFeedback.heavyImpact();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final now = DateTime.now().toUtc();
      final String teacherName = auth.profile?['full_name'] ?? "المدرس";
      
      final sessionData = {
        'subject_name': "بث مباشر سريع - ${intl.DateFormat('jm').format(DateTime.now())}",
        'teacher_id': auth.user!.id,
        'start_time': now.toIso8601String(),
        'end_time': now.add(const Duration(hours: 1)).toIso8601String(),
        'class_code': (DateTime.now().millisecondsSinceEpoch % 1000000).toString(),
        'status': 'active',
        'is_recording_enabled': true,
      };

      final newSessionMap = await db.saveSession(sessionData);
      
      if (newSessionMap != null) {
        final newSession = SessionModel.fromMap(newSessionMap);
        await db.toggleRoomStatus(newSession.id, true);
        
        if (!mounted) return;
        Navigator.pop(context); 
        
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (_) => VideoRoomController(
              title: newSession.subjectName,
              roomName: "room_${newSession.id}",
              userName: "أ. $teacherName",
              userId: auth.user!.id,
              isTeacher: true,
              sessionId: newSession.id,
            ),
            child: VideoRoomScreen(
              title: newSession.subjectName,
              roomName: "room_${newSession.id}",
              userName: "أ. $teacherName",
              userId: auth.user!.id,
              isTeacher: true,
              sessionId: newSession.id,
            ),
          )
        ));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل بدء البث السريع")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final name = authProvider.profile?['full_name'] ?? "المدرس";
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildHeader(name),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 40 : 20,
                            vertical: 30,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatsOverview(),
                              const SizedBox(height: 32),
                              if (_activeSession != null) ...[
                                 _buildSectionTitle("البث المباشر الآن", isLive: true),
                                 const SizedBox(height: 16),
                                 _buildActiveSessionCard(name),
                                 const SizedBox(height: 32),
                              ],
                              _buildSectionTitle("الإجراءات السريعة"),
                              const SizedBox(height: 16),
                              _buildSmartQuickActions(),
                              const SizedBox(height: 32),
                              if (_nextSession != null) ...[
                                _buildSectionTitle("الحصة القادمة"),
                                const SizedBox(height: 16),
                                _buildNextSessionCard(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(String name) {
    return SliverAppBar(
      expandedHeight: 120, pinned: true, elevation: 0,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("لوحة التحكم", style: TextStyle(color: Colors.grey, fontSize: 10)),
            Text("أهلاً، أ. $name", style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      actions: [
        Tooltip(
          message: "بدء بث مباشر الآن",
          child: IconButton(
            onPressed: _createInstantLive,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.bolt_rounded, color: Colors.red, size: 22),
            ),
          ),
        ),
        IconButton(
          onPressed: _showAddSessionDialog,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.add_rounded, color: Colors.blue, size: 20),
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildSectionTitle(String title, {bool isLive = false}) {
    return Row(
      children: [
        if (isLive) 
          FadeTransition(
            opacity: _pulseController,
            child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
          ),
        if (isLive) const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
      ],
    );
  }

  Widget _buildStatsOverview() {
    return Row(
      children: [
        Expanded(child: TeacherStatCard(title: "الطلاب", value: _totalStudents.toString(), icon: Icons.people_outline_rounded, color: Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: TeacherStatCard(title: "حصص اليوم", value: _sessions.length.toString(), icon: Icons.videocam_outlined, color: Colors.orange)),
      ],
    );
  }

  Widget _buildActiveSessionCard(String teacherName) {
    final isDesktop = Responsive.isDesktop(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red.shade700, Colors.red.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: isDesktop 
      ? Row(
          children: [
            const CircleAvatar(backgroundColor: Colors.white24, radius: 30, child: Icon(Icons.bolt_rounded, color: Colors.white, size: 35)),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_activeSession!.subjectName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text("الحصة جارية الآن... الطلاب في انتظارك", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(width: 24),
            ElevatedButton(
              onPressed: () => _startLive(_activeSession!, teacherName),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text("دخول البث المباشر الآن", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        )
      : Column(
          children: [
            Row(
              children: [
                const CircleAvatar(backgroundColor: Colors.white24, radius: 25, child: Icon(Icons.bolt_rounded, color: Colors.white, size: 30)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_activeSession!.subjectName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text("الحصة جارية الآن... الطلاب في انتظارك", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _startLive(_activeSession!, teacherName),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade700,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text("دخول البث المباشر الآن", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
    );
  }

  Widget _buildSmartQuickActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton("التحضير", Icons.how_to_reg_outlined, Colors.blue, 'attendance'),
          _buildActionButton("التقارير", Icons.bar_chart_rounded, Colors.green, 'reports'),
          _buildActionButton("الجدول", Icons.calendar_today_rounded, Colors.purple, 'schedule'),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, String type) {
    return InkWell(
      onTap: () => _handleQuickAction(type),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNextSessionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.calendar_month_outlined, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nextSession!.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text("تبدأ في ${intl.DateFormat('hh:mm a').format(_nextSession!.startTime)}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  void _handleQuickAction(String type) {
    HapticFeedback.lightImpact();
    if (type == 'reports') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherReportsScreen()));
      return;
    }
    if (type == 'schedule') {
      // Logic for schedule if needed
      return;
    }
    if (_sessions.isEmpty) {
      _showNoSessionAlert();
      return;
    }
    _showSessionPicker(type);
  }

  void _showNoSessionAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("لا توجد حصص مسجلة لديك حالياً"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        )
    );
  }

  void _showSessionPicker(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text("اختر الحصة للمتابعة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final s = _sessions[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.videocam_rounded, color: Colors.blue)),
                    title: Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(intl.DateFormat('hh:mm a').format(s.startTime)),
                    onTap: () { Navigator.pop(context); _navigateToActionScreen(type, s); },
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
    }
  }

  Future<void> _startLive(SessionModel session, String teacherName) async {
    HapticFeedback.mediumImpact();
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      await db.toggleRoomStatus(session.id, true);
      if (!mounted) return;

      Navigator.push(context, MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (_) => VideoRoomController(
              title: session.subjectName,
              roomName: "room_${session.id}",
              userName: "أ. $teacherName",
              userId: auth.user!.id,
              isTeacher: true,
              sessionId: session.id,
            ),
            child: VideoRoomScreen(
              title: session.subjectName,
              roomName: "room_${session.id}",
              userName: "أ. $teacherName",
              userId: auth.user!.id,
              isTeacher: true,
              sessionId: session.id,
            ),
          )
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل بدء البث")));
    }
  }

  void _showAddSessionDialog() {
    final nameController = TextEditingController();
    DateTime startDate = DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();
    int selectedDuration = 60;
    bool isRecording = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text("جدولة حصة جديدة", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController, 
                  decoration: InputDecoration(
                    labelText: "اسم الحصة", 
                    prefixIcon: const Icon(Icons.edit_note_outlined), 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))
                  ),
                ),
                const SizedBox(height: 20),
                _buildDateTimePicker(label: "موقت البدء", date: startDate, time: startTime, onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (d != null) {
                    final t = await showTimePicker(context: context, initialTime: startTime);
                    if (t != null) setDS(() { startDate = d; startTime = t; });
                  }
                }),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  value: selectedDuration,
                  decoration: InputDecoration(labelText: "المدة", border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                  items: [30, 45, 60, 90, 120].map((v) => DropdownMenuItem(value: v, child: Text("$v دقيقة"))).toList(),
                  onChanged: (v) => setDS(() => selectedDuration = v!),
                ),
                const SizedBox(height: 10),
                SwitchListTile(title: const Text("تسجيل الحصة"), value: isRecording, onChanged: (v) => setDS(() => isRecording = v), activeColor: Colors.red),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                final start = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute).toUtc();
                final db = Provider.of<DatabaseService>(context, listen: false);
                await db.saveSession({
                  'subject_name': nameController.text,
                  'teacher_id': Provider.of<AuthProvider>(context, listen: false).user!.id,
                  'start_time': start.toIso8601String(),
                  'end_time': start.add(Duration(minutes: selectedDuration)).toIso8601String(),
                  'class_code': (DateTime.now().millisecondsSinceEpoch % 1000000).toString(),
                  'status': 'waiting',
                  'is_recording_enabled': isRecording,
                });
                Navigator.pop(context);
                _loadData();
              },
              child: const Text("حفظ"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({required String label, required DateTime date, required TimeOfDay time, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, 
      child: Container(
        padding: const EdgeInsets.all(16), 
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: Colors.blue), 
            const SizedBox(width: 12), 
            Text("${intl.DateFormat('yyyy-MM-dd').format(date)} ${time.format(context)}", style: const TextStyle(fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }
}
