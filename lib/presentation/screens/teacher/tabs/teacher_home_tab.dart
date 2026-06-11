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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final name = authProvider.profile?['full_name'] ?? "المعلم";
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF102A43)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildTopBar(name, isDesktop),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 40 : 20,
                      vertical: 30,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildStatsRow(isDesktop),
                        const SizedBox(height: 40),
                        
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader("البث المباشر الآن", isLive: _activeSession != null),
                                  const SizedBox(height: 20),
                                  _activeSession != null 
                                    ? _buildPremiumLiveCard(name, isDesktop)
                                    : _buildEmptyLiveState(),
                                  
                                  const SizedBox(height: 40),
                                  _buildSectionHeader("الحصص القادمة", icon: Icons.event_note_rounded),
                                  const SizedBox(height: 20),
                                  _nextSession != null 
                                    ? _buildUpcomingCard(isDesktop)
                                    : _buildNoUpcomingState(),
                                ],
                              ),
                            ),
                            if (isDesktop) const SizedBox(width: 30),
                            if (isDesktop)
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader("الإجراءات السريعة", icon: Icons.offline_bolt_rounded),
                                    const SizedBox(height: 20),
                                    _buildQuickActionsGrid(),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (!isDesktop) ...[
                          const SizedBox(height: 40),
                          _buildSectionHeader("الإجراءات السريعة", icon: Icons.offline_bolt_rounded),
                          const SizedBox(height: 20),
                          _buildQuickActionsGrid(),
                        ],
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTopBar(String name, bool isDesktop) {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 100,
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 20),
          alignment: Alignment.centerRight,
          child: Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("أهلاً بك، أستاذ", style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.w500)),
                  Text(name, style: const TextStyle(color: Color(0xFF102A43), fontSize: 24, fontFamily: 'Cairo', fontWeight: FontWeight.w900)),
                ],
              ),
              const Spacer(),
              _buildHeaderAction(Icons.bolt_rounded, Colors.red, "بث سريع", _createInstantLive),
              const SizedBox(width: 10),
              _buildHeaderAction(Icons.add_rounded, Colors.blue, "جدولة حصة", _showAddSessionDialog),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isDesktop) {
    return Row(
      children: [
        Expanded(child: TeacherStatCard(title: "إجمالي الطلاب", value: _totalStudents.toString(), icon: Icons.people_rounded, color: const Color(0xFF2196F3))),
        const SizedBox(width: 20),
        Expanded(child: TeacherStatCard(title: "حصص اليوم", value: _sessions.length.toString(), icon: Icons.video_library_rounded, color: const Color(0xFFFF9800))),
        if (isDesktop) const SizedBox(width: 20),
        if (isDesktop)
          Expanded(child: TeacherStatCard(title: "متصل الآن", value: "3", icon: Icons.sensors_rounded, color: const Color(0xFF4CAF50))),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {bool isLive = false, IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: const Color(0xFF102A43)),
          const SizedBox(width: 10),
        ],
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF102A43), fontFamily: 'Cairo')),
        if (isLive) ...[
          const SizedBox(width: 12),
          FadeTransition(
            opacity: _pulseController,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.shade200, width: 0.5)),
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text("مباشر", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPremiumLiveCard(String teacherName, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF102A43), Color(0xFF243B53), Color(0xFF334E68)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: const Color(0xFF102A43).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned(right: -20, top: -20, child: Icon(Icons.bolt_rounded, color: Colors.white.withOpacity(0.05), size: 150)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 28)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_clean(_activeSession?.subjectName), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis),
                        Text("بدأت في ${_formatTimeArabic(_activeSession?.startTime ?? DateTime.now())}", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, fontFamily: 'Cairo')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _navigateToLive(_activeSession!, teacherName),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF102A43), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                      child: const Text("دخول القاعة الآن", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
                    ),
                  ),
                  const SizedBox(width: 15),
                  InkWell(
                    onTap: () {
                      if (_activeSession != null) {
                        final link = "https://learning-system-jet.vercel.app/join/${_activeSession!.classCode}";
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("تم نسخ رابط الحصة الحقيقي ✅", style: TextStyle(fontFamily: 'Cairo')),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                        HapticFeedback.mediumImpact();
                      }
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.all(15), 
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), 
                      child: const Icon(Icons.share_rounded, color: Colors.white)
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLiveState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.blueGrey.withOpacity(0.1))),
      child: Column(
        children: [
          Icon(Icons.videocam_off_outlined, size: 50, color: Colors.blueGrey.shade200),
          const SizedBox(height: 15),
          const Text("لا توجد حصص جارية حالياً", style: TextStyle(fontFamily: 'Cairo', color: Colors.blueGrey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildUpcomingCard(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF102A43))),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_clean(_nextSession?.subjectName), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF102A43), fontFamily: 'Cairo')),
                const SizedBox(height: 4),
                Text("تبدأ الساعة: ${_formatTimeArabic(_nextSession?.startTime ?? DateTime.now())}", style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13, fontFamily: 'Cairo')),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.blueGrey),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      (label: "التحضير", icon: Icons.fact_check_rounded, color: const Color(0xFF2196F3), type: 'attendance'),
      (label: "التقارير", icon: Icons.analytics_rounded, color: const Color(0xFF00C853), type: 'reports'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.2),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: () => _handleQuickAction(action.type),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: action.color.withOpacity(0.08), shape: BoxShape.circle), child: Icon(action.icon, color: action.color, size: 24)),
                const SizedBox(height: 12),
                Text(action.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF102A43), fontFamily: 'Cairo')),
              ],
            ),
          ),
        );
      },
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
              const Padding(padding: EdgeInsets.all(20), child: Text("لا توجد حصص مسجلة بعد", style: TextStyle(fontFamily: 'Cairo')))
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

  Widget _buildNoUpcomingState() {
    return const Text("لا توجد حصص مجدولة قريباً", style: TextStyle(color: Colors.blueGrey, fontFamily: 'Cairo'));
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
}
