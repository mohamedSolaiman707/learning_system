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

  // --- دوال العمليات (Actions) ---

  Future<void> _createInstantLive() async {
    HapticFeedback.heavyImpact();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.blue)),
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
        Navigator.pop(context); // إغلاق الـ Loading

        _navigateToLive(newSession, teacherName);
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل بدء البث السريع")));
    }
  }

  void _navigateToLive(SessionModel session, String teacherName) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
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
  }

  // --- بناء الواجهة (UI) ---

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final name = authProvider.profile?['full_name'] ?? "المدرس";
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
        onRefresh: _loadData,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(name, isDesktop),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : 20,
                    vertical: 20,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildStatsOverview(isDesktop || isTablet),
                      const SizedBox(height: 32),

                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_activeSession != null)
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle("البث المباشر الآن", isLive: true),
                                    const SizedBox(height: 16),
                                    _buildActiveSessionCard(name, isDesktop),
                                  ],
                                ),
                              ),
                            if (_activeSession != null) const SizedBox(width: 24),
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle("الإجراءات السريعة"),
                                  const SizedBox(height: 16),
                                  _buildSmartQuickActions(isVertical: true),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        if (_activeSession != null) ...[
                          _buildSectionTitle("البث المباشر الآن", isLive: true),
                          const SizedBox(height: 16),
                          _buildActiveSessionCard(name, isDesktop),
                          const SizedBox(height: 32),
                        ],
                        _buildSectionTitle("الإجراءات السريعة"),
                        const SizedBox(height: 16),
                        _buildSmartQuickActions(isVertical: false),
                      ],

                      const SizedBox(height: 32),
                      if (_nextSession != null) ...[
                        _buildSectionTitle("الحصة القادمة"),
                        const SizedBox(height: 16),
                        _buildNextSessionCard(isDesktop),
                      ],
                      const SizedBox(height: 50),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name, bool isDesktop) {
    return SliverAppBar(
      expandedHeight: isDesktop ? 150 : 120,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 20, vertical: 15),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("لوحة التحكم", style: TextStyle(color: Colors.grey, fontSize: isDesktop ? 12 : 10)),
            Text("أهلاً، أ. $name", style: TextStyle(color: Colors.black, fontSize: isDesktop ? 22 : 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      actions: [
        _buildHeaderAction(Icons.bolt_rounded, Colors.red, "بث سريع", _createInstantLive),
        _buildHeaderAction(Icons.add_rounded, Colors.blue, "جدولة حصة", _showAddSessionDialog),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _buildHeaderAction(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildStatsOverview(bool isWide) {
    return Row(
      children: [
        Expanded(child: TeacherStatCard(title: "الطلاب", value: _totalStudents.toString(), icon: Icons.people_outline_rounded, color: Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: TeacherStatCard(title: "حصص اليوم", value: _sessions.length.toString(), icon: Icons.videocam_outlined, color: Colors.orange)),
        if (isWide) ...[
          const SizedBox(width: 16),
          const Expanded(child: TeacherStatCard(title: "متصل الآن", value: "3", icon: Icons.online_prediction, color: Colors.green)),
        ]
      ],
    );
  }

  Widget _buildActiveSessionCard(String teacherName, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red.shade700, Colors.red.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(isDesktop ? 32 : 24),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                  backgroundColor: Colors.white24,
                  radius: isDesktop ? 35 : 25,
                  child: Icon(Icons.bolt_rounded, color: Colors.white, size: isDesktop ? 40 : 30)
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_activeSession!.subjectName, style: TextStyle(color: Colors.white, fontSize: isDesktop ? 22 : 18, fontWeight: FontWeight.bold)),
                    const Text("الحصة جارية الآن...", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _navigateToLive(_activeSession!, teacherName),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red.shade700,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("دخول البث المباشر الآن", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartQuickActions({bool isVertical = false}) {
    final actions = [
      _buildActionButton("التحضير", Icons.how_to_reg_outlined, Colors.blue, 'attendance'),
      _buildActionButton("التقارير", Icons.bar_chart_rounded, Colors.green, 'reports'),
      _buildActionButton("الجدول", Icons.calendar_today_rounded, Colors.purple, 'schedule'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100)
      ),
      child: isVertical
          ? Column(children: actions.map((a) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: a)).toList())
          : Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: actions),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, String type) {
    return InkWell(
      onTap: () => _handleQuickAction(type),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNextSessionCard(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
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
                Text(_nextSession!.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("تبدأ في ${intl.DateFormat('hh:mm a').format(_nextSession!.startTime)}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey),
        ],
      ),
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
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- دوال المساعدة الإضافية ---

  void _handleQuickAction(String type) {
    if (type == 'reports') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherReportsScreen()));
      return;
    }
    if (_sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا توجد حصص مسجلة")));
      return;
    }
    _showSessionPicker(type);
  }

  void _showSessionPicker(String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _sessions.length,
          itemBuilder: (context, i) => ListTile(
            title: Text(_sessions[i].subjectName),
            onTap: () {
              Navigator.pop(context);
              if (type == 'attendance') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen(sessionId: _sessions[i].id, subjectName: _sessions[i].subjectName)));
              }
            },
          ),
        ),
      ),
    );
  }

  void _showAddSessionDialog() {
    final nameController = TextEditingController();
    DateTime startDate = DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إضافة حصة جديدة"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "اسم المادة")),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                if (d != null) startDate = d;
              },
              child: const Text("اختر التاريخ"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final db = Provider.of<DatabaseService>(context, listen: false);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await db.saveSession({
                'subject_name': nameController.text,
                'teacher_id': auth.user!.id,
                'start_time': startDate.toIso8601String(),
                'end_time': startDate.add(const Duration(hours: 1)).toIso8601String(),
                'status': 'waiting',
              });
              Navigator.pop(context);
              _loadData();
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }
}