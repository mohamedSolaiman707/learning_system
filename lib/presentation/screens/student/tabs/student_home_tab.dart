import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shimmer/shimmer.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/assignments_service.dart';
import '../../../../core/models/session_model.dart';
import '../widgets/next_class_card.dart';
import '../widgets/upcoming_class_item.dart';
import '../../video_room/video_room_screen.dart';
import '../../video_room/waiting_room_screen.dart';
import '../assignments/student_assignments_screen.dart';
import '../resources/student_resources_screen.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  bool _isLoading = true;
  List<SessionModel> _enrolledSessions = [];
  List<SessionModel> _allActiveSessions = [];
  SessionModel? _nextSession;
  int _pendingAssignmentsCount = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStudentData(initial: true);
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadStudentData(initial: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStudentData({bool initial = true}) async {
    if (!mounted) return;
    if (initial) setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      final assignService = AssignmentsService();
      
      if (auth.user != null) {
        // 1. جلب حصص الطالب المسجل فيها
        final enrolledResponse = await db.getStudentSchedule(auth.user!.id);
        
        // 2. جلب جميع الحصص المباشرة حالياً في النظام
        final activeResponse = await db.getActiveSessions();

        if (mounted) {
          setState(() {
            final now = DateTime.now();
            
            // فلترة الحصص: جلب فقط الحصص التي لم تنتهِ بعد (وقتها القادم أو الحالي)
            _enrolledSessions = enrolledResponse
                .map((e) => SessionModel.fromMap(e['sessions']))
                .where((s) => s.endTime.isAfter(now)) 
                .toList();
            
            _enrolledSessions.sort((a, b) => a.startTime.compareTo(b.startTime));

            _allActiveSessions = activeResponse.map((e) => SessionModel.fromMap(e)).toList();

            try {
              // الأولوية للحصص المباشرة من حصص الطالب
              _nextSession = _enrolledSessions.firstWhere(
                (s) => (s.isLive || s.isActive) && s.endTime.isAfter(now),
                orElse: () => _enrolledSessions.firstWhere((s) => s.endTime.isAfter(now)),
              );
            } catch (_) {
              _nextSession = null;
            }
            
            if (initial) _isLoading = false;
          });

          // حساب الواجبات المعلقة (يمكن تحسينها لاحقاً لتعمل في الخلفية)
          int pendingCount = 0;
          for (var session in _enrolledSessions) {
             final assignments = await assignService.getAssignments(session.id);
             for (var assignment in assignments) {
               final submission = await assignService.getStudentSubmission(assignment.id, auth.user!.id);
               if (submission == null) {
                 pendingCount++;
               }
             }
          }
          if (mounted) setState(() => _pendingAssignmentsCount = pendingCount);
        }
      }
    } catch (e) {
      if (mounted && initial) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinActiveSession(SessionModel session) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    // تسجيل الطالب في الحصة أولاً إذا لم يكن مسجلاً
    await db.enrollStudentBySessionId(auth.user!.id, session.id);
    
    if (!mounted) return;

    if (session.status == 'waiting') {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => WaitingRoomScreen(
          session: session,
          userName: auth.profile?['full_name'] ?? "الطالب",
          userId: auth.user!.id,
        ),
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => VideoRoomScreen(
          title: "بث مباشر: ${session.subjectName}",
          roomName: "room_${session.id}",
          userName: auth.profile?['full_name'] ?? "الطالب",
          userId: auth.user!.id,
          isTeacher: false,
          sessionId: session.id,
        ),
      ));
    }
  }

  void _showSessionOptions(SessionModel session) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.subjectName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildOptionTile(IconlyLight.document, "الواجبات المدرسية", Colors.blue, () async {
              Navigator.pop(context);
              await Navigator.push(context, MaterialPageRoute(builder: (context) => StudentAssignmentsScreen(sessionId: session.id, subjectName: session.subjectName)));
              _loadStudentData(initial: false);
            }),
            const Divider(),
            _buildOptionTile(IconlyLight.folder, "المصادر والكتب", Colors.orange, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => StudentResourcesScreen(sessionId: session.id, subjectName: session.subjectName)));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.profile?['full_name'] ?? "الطالب";
    final userId = authProvider.user?.id ?? ""; 

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading 
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: () => _loadStudentData(initial: true),
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(userName),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(Responsive.isMobile(context) ? 16 : 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeSection(userName),
                          const SizedBox(height: 30),
                          
                          // قسم الحصص المباشرة الآن (لأي حصة في النظام)
                          if (_allActiveSessions.isNotEmpty) ...[
                            _buildSectionHeader("بث مباشر الآن 🔴", isLive: true),
                            const SizedBox(height: 15),
                            _buildActiveSessionsList(),
                            const SizedBox(height: 30),
                          ],

                          if (_nextSession != null) ...[
                            _buildSectionHeader("حصتك القادمة"),
                            const SizedBox(height: 15),
                            GestureDetector(
                              onTap: () => _showSessionOptions(_nextSession!),
                              child: _buildNextClassSection(userName, userId),
                            ),
                          ] else
                            _buildNoClassesCard(),
                          
                          const SizedBox(height: 40),
                          _buildStatsAndProgress(),
                          const SizedBox(height: 40),
                          if (_enrolledSessions.isNotEmpty) ...[
                            _buildSectionHeader("جدول حصصك القادمة"),
                            const SizedBox(height: 15),
                            _buildUpcomingGrid(),
                          ],
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
      expandedHeight: 120, floating: true, pinned: true,
      backgroundColor: Colors.white, elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
        title: Text("الرئيسية", style: TextStyle(color: Colors.black.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      actions: [
        IconButton(onPressed: () {}, icon: const Badge(child: Icon(IconlyLight.notification))),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : "U", style: const TextStyle(color: Colors.blue)),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(String name) {
    int todayCount = _enrolledSessions.where((s) {
      final now = DateTime.now();
      return s.startTime.day == now.day && s.startTime.month == now.month;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("أهلاً بك، $name 👋", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(
          todayCount > 0 ? "لديك $todayCount حصص متبقية اليوم." : "لا توجد حصص مجدولة حالياً.",
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {bool isLive = false}) {
    return Row(
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isLive ? Colors.red : Colors.black87)),
        if (isLive) ...[
          const SizedBox(width: 8),
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
        ]
      ],
    );
  }

  Widget _buildActiveSessionsList() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _allActiveSessions.length,
        itemBuilder: (context, index) {
          final session = _allActiveSessions[index];
          return Container(
            width: 280,
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF9C27B0)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(session.subjectName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)), child: const Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                  ],
                ),
                Text(session.teacherName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ElevatedButton(
                  onPressed: () => _joinActiveSession(session),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.purple, minimumSize: const Size(double.infinity, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text("انضمام الآن", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNextClassSection(String userName, String userId) {
    return NextClassCard(
      subject: _nextSession!.subjectName,
      teacher: _nextSession!.teacherName,
      startTime: intl.DateFormat('hh:mm a').format(_nextSession!.startTime),
      isLive: _nextSession!.isLive || _nextSession!.isActive,
      onJoin: () => _joinActiveSession(_nextSession!),
    );
  }

  Widget _buildNoClassesCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.1))),
      child: Column(
        children: [
          Icon(IconlyLight.calendar, size: 50, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text("لا توجد حصص قادمة حالياً", style: TextStyle(color: Colors.grey, fontSize: 16)),
          const Text("سوف تظهر الحصص هنا بمجرد أن تبدأ", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatsAndProgress() {
    return Row(
      children: [
        Expanded(child: _buildStatItem("حصصي", "${_enrolledSessions.length}", Icons.collections_bookmark, Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatItem("واجباتي", "$_pendingAssignmentsCount", Icons.assignment, Colors.orange)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _buildUpcomingGrid() {
    final upcoming = _enrolledSessions.where((s) => s.id != _nextSession?.id).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.isMobile(context) ? 1 : 2,
        crossAxisSpacing: 16, mainAxisSpacing: 16, mainAxisExtent: 100,
      ),
      itemCount: upcoming.length,
      itemBuilder: (context, index) {
        final session = upcoming[index];
        final diff = session.endTime.difference(session.startTime).inMinutes;
        return InkWell(
          onTap: () => _showSessionOptions(session),
          child: UpcomingClassItem(
            subject: session.subjectName,
            teacher: session.teacherName,
            time: intl.DateFormat('hh:mm a').format(session.startTime),
            duration: "$diff دقيقة",
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(height: 150, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
            const SizedBox(height: 20),
            Row(children: [Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))), const SizedBox(width: 10), Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))))]),
            const SizedBox(height: 30),
            ...List.generate(3, (i) => Container(height: 70, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
          ],
        ),
      ),
    );
  }
}
