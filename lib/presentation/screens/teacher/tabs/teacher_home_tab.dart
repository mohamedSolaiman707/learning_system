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
          db.getTeacherSessionsAll(auth.user!.id),
          db.getTeacherStats(auth.user!.id),
        ]);

        if (mounted) {
          setState(() {
            _sessions = (results[0] as List).map((e) => SessionModel.fromMap(e)).toList();
            _totalStudents = (results[1] as Map<String, dynamic>)['totalStudents'] ?? 0;

            final now = DateTime.now();

            // طريقة آمنة لجلب الحصة الحالية والقادمة
            try {
              _activeSession = _sessions.where((s) => 
                s.status == 'active' || 
                (s.startTime.isBefore(now) && s.endTime.isAfter(now) && s.status != 'ended')
              ).first;
            } catch (_) {
              _activeSession = null;
            }

            try {
              _nextSession = _sessions.where((s) => 
                s.startTime.isAfter(now) && s.id != _activeSession?.id && s.status != 'ended'
              ).first;
            } catch (_) {
              _nextSession = null;
            }

            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading teacher data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _clean(String? text) {
    if (text == null) return "";
    return text.replaceAll("AM", "صباحاً").replaceAll("PM", "مساءً");
  }

  String _formatTimeArabic(DateTime time) {
    String formatted = intl.DateFormat('hh:mm').format(time.toLocal());
    return "$formatted ${time.toLocal().hour < 12 ? "صباحاً" : "مساءً"}";
  }

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
      final now = DateTime.now();
      final String teacherName = auth.profile?['full_name'] ?? "المدرس";

      final sessionData = {
        'subject_name': "بث مباشر سريع - ${_formatTimeArabic(now)}",
        'teacher_id': auth.user!.id,
        'start_time': now.toUtc().toIso8601String(), 
        'end_time': now.add(const Duration(hours: 1)).toUtc().toIso8601String(),
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

        _navigateToLive(newSession, teacherName);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل بدء البث السريع")));
    }
  }

  void _showAddSessionDialog() {
    final nameController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    int selectedDuration = 1; 

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text("جدولة حصة جديدة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController, 
                      style: const TextStyle(fontFamily: 'Cairo'),
                      decoration: InputDecoration(
                        labelText: "اسم المادة", 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        prefixIcon: const Icon(Icons.book_outlined)
                      )
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, color: Color(0xFF102A43)),
                      title: const Text("موعد الحصة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      subtitle: Text("${intl.DateFormat('yyyy/MM/dd').format(selectedDate)} الساعة ${_formatTimeArabic(DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute))}", style: const TextStyle(fontFamily: 'Cairo')),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context, 
                          initialDate: selectedDate, 
                          firstDate: DateTime.now(), 
                          lastDate: DateTime.now().add(const Duration(days: 365))
                        );
                        if (d != null) {
                          final t = await showTimePicker(context: context, initialTime: selectedTime);
                          if (t != null) {
                            setDialogState(() {
                              selectedDate = d;
                              selectedTime = t;
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedDuration,
                      style: const TextStyle(fontFamily: 'Cairo', color: Colors.black),
                      decoration: InputDecoration(
                        labelText: "مدة الحصة (ساعات)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        prefixIcon: const Icon(Icons.timer_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text("ساعة واحدة")),
                        DropdownMenuItem(value: 2, child: Text("ساعتان")),
                        DropdownMenuItem(value: 3, child: Text("3 ساعات")),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedDuration = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;
                    
                    final startLocal = DateTime(
                      selectedDate.year, selectedDate.month, selectedDate.day,
                      selectedTime.hour, selectedTime.minute
                    );
                    
                    final endLocal = startLocal.add(Duration(hours: selectedDuration));

                    final db = Provider.of<DatabaseService>(context, listen: false);
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    await db.saveSession({
                      'subject_name': nameController.text.trim(),
                      'teacher_id': auth.user!.id,
                      'start_time': startLocal.toUtc().toIso8601String(), 
                      'end_time': endLocal.toUtc().toIso8601String(),
                      'status': 'waiting',
                      'class_code': (DateTime.now().millisecondsSinceEpoch % 1000000).toString(),
                    });
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم جدولة الحصة بنجاح ✅', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF102A43), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text("حفظ الحصة", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final name = authProvider.profile?['full_name'] ?? "المدرس";
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF102A43)))
          : RefreshIndicator(
        onRefresh: _loadData,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
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
                      _buildStatsOverview(isDesktop, isTablet),
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
                      const SizedBox(height: 60),
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
      expandedHeight: isDesktop ? 120 : 100,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 20, vertical: 15),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("أهلاً، أ. $name", style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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

  Widget _buildStatsOverview(bool isDesktop, bool isTablet) {
    int crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 2);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isDesktop ? 2.5 : 1.3, 
      children: [
        TeacherStatCard(title: "الطلاب", value: _totalStudents.toString(), icon: Icons.people_outline_rounded, color: Colors.blue),
        TeacherStatCard(title: "حصص اليوم", value: _sessions.length.toString(), icon: Icons.videocam_outlined, color: Colors.orange),
        if (isDesktop || isTablet)
          const TeacherStatCard(title: "متصل الآن", value: "3", icon: Icons.online_prediction, color: Colors.green),
      ],
    );
  }

  Widget _buildActiveSessionCard(String teacherName, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF102A43), const Color(0xFF243B53)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF102A43).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: isDesktop 
      ? Row(
          children: [
            _buildActiveInfo(isDesktop),
            const Spacer(),
            SizedBox(width: 200, child: _buildEnterButton(teacherName))
          ],
        )
      : Column(
          children: [
            _buildActiveInfo(isDesktop),
            const SizedBox(height: 24),
            _buildEnterButton(teacherName),
          ],
        ),
    );
  }

  Widget _buildActiveInfo(bool isDesktop) {
    return Row(
      children: [
        CircleAvatar(
            backgroundColor: Colors.white12,
            radius: isDesktop ? 30 : 25,
            child: Icon(Icons.bolt_rounded, color: Colors.white, size: isDesktop ? 35 : 30)
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_clean(_activeSession?.subjectName ?? ""), style: TextStyle(color: Colors.white, fontSize: isDesktop ? 20 : 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            const Text("الحصة جارية الآن...", style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Cairo')),
          ],
        ),
      ],
    );
  }

  Widget _buildEnterButton(String teacherName) {
    return ElevatedButton(
      onPressed: () => _navigateToLive(_activeSession!, teacherName),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF102A43),
        minimumSize: const Size(double.infinity, 50),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text("دخول البث الآن", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSmartQuickActions({bool isVertical = false}) {
    final actions = [
      _buildActionButton("التحضير", Icons.how_to_reg_outlined, Colors.blue, 'attendance'),
      _buildActionButton("التقارير", Icons.bar_chart_rounded, Colors.green, 'reports'),
      _buildActionButton("الجدول", Icons.calendar_today_rounded, Colors.purple, 'schedule'),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
      ),
      child: isVertical
          ? Column(children: actions.map((a) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: a)).toList())
          : Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: actions),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, String type) {
    return InkWell(
      onTap: () => _handleQuickAction(type),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildNextSessionCard(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.calendar_month_outlined, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_clean(_nextSession?.subjectName ?? ""), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
                Text("تبدأ في ${_formatTimeArabic(_nextSession?.startTime ?? DateTime.now())}", style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Cairo')),
              ],
            ),
          ),
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
            child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
          ),
        if (isLive) const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      ],
    );
  }

  void _handleQuickAction(String type) {
    if (type == 'reports') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherReportsScreen()));
      return;
    }
    _showSessionPicker(type);
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
            const Text("اختر الحصة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            const SizedBox(height: 16),
            if (_sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("لا توجد حصص مسجلة بعد", style: TextStyle(fontFamily: 'Cairo')),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sessions.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(_clean(_sessions[i].subjectName), style: const TextStyle(fontFamily: 'Cairo')),
                    onTap: () {
                      Navigator.pop(context);
                      if (type == 'attendance') {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen(sessionId: _sessions[i].id, subjectName: _sessions[i].subjectName)));
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
