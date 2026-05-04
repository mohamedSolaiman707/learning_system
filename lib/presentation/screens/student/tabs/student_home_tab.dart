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
import '../assignments/student_assignments_screen.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  bool _isLoading = true;
  List<SessionModel> _sessions = [];
  SessionModel? _nextSession;
  int _pendingAssignmentsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      final assignService = AssignmentsService();
      
      if (auth.user != null) {
        final response = await db.getStudentSchedule(auth.user!.id);
        
        if (mounted) {
          setState(() {
            _sessions = response.map((e) => SessionModel.fromMap(e['sessions'])).toList();
            _sessions.sort((a, b) => a.startTime.compareTo(b.startTime));

            final now = DateTime.now();
            try {
              _nextSession = _sessions.firstWhere((s) => s.endTime.isAfter(now));
            } catch (_) {
              _nextSession = null;
            }
          });

          // جلب عدد الواجبات لكل المواد المشترك فيها
          int totalAssignments = 0;
          for (var session in _sessions) {
             final assignments = await assignService.getAssignments(session.id);
             totalAssignments += assignments.length;
          }
          
          if (mounted) {
            setState(() {
              _pendingAssignmentsCount = totalAssignments;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final profile = authProvider.profile;
    final userName = profile?['full_name'] ?? "الطالب";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading 
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _loadStudentData,
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
                          if (_nextSession != null) 
                            _buildNextClassSection(userName)
                          else
                            _buildNoClassesCard(),
                          const SizedBox(height: 40),
                          _buildStatsAndProgress(),
                          const SizedBox(height: 40),
                          if (_sessions.isNotEmpty) ...[
                            _buildUpcomingClassesHeader(),
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
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
        title: Text(
          "الرئيسية",
          style: TextStyle(
            color: Colors.black.withOpacity(0.8),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Badge(child: Icon(IconlyLight.notification)),
        ),
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
    int todayCount = _sessions.where((s) {
      final now = DateTime.now();
      return s.startTime.day == now.day && s.startTime.month == now.month;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "مرحباً بك مجدداً، $name 👋",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          todayCount > 0 ? "لديك $todayCount حصص اليوم، استعد جيداً!" : "لا توجد حصص مجدولة لليوم.",
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildNextClassSection(String userName) {
    return NextClassCard(
      subject: _nextSession!.subjectName,
      teacher: _nextSession!.teacherName,
      startTime: intl.DateFormat('hh:mm a').format(_nextSession!.startTime),
      isLive: _nextSession!.isLive,
      onJoin: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => VideoRoomScreen(
            title: "بث مباشر: ${_nextSession!.subjectName}",
            roomName: "room_${_nextSession!.id}",
            userName: userName,
          ),
        ));
      },
    );
  }

  Widget _buildNoClassesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: const Column(
        children: [
          Icon(IconlyLight.calendar, size: 50, color: Colors.grey),
          SizedBox(height: 15),
          Text("لا توجد حصص قادمة حالياً", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildStatsAndProgress() {
    return Responsive(
      mobile: Column(
        children: [
          _buildStatItem("الحصص المسجلة", "${_sessions.length}", Icons.collections_bookmark, Colors.green),
          const SizedBox(height: 12),
          _buildStatItem("الواجبات", "$_pendingAssignmentsCount", Icons.assignment, Colors.orange),
        ],
      ),
      desktop: Row(
        children: [
          Expanded(child: _buildStatItem("الحصص المسجلة", "${_sessions.length}", Icons.collections_bookmark, Colors.green)),
          const SizedBox(width: 20),
          Expanded(child: _buildStatItem("الواجبات", "$_pendingAssignmentsCount", Icons.assignment, Colors.orange)),
          const SizedBox(width: 20),
          Expanded(child: _buildStatItem("التقدم", "100%", Icons.auto_graph, Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingClassesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("حصصك القادمة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: () {}, child: const Text("عرض الكل")),
      ],
    );
  }

  Widget _buildUpcomingGrid() {
    final upcoming = _sessions.where((s) => s.id != _nextSession?.id).toList();
    
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = Responsive.isDesktop(context) ? 3 : (Responsive.isTablet(context) ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 110,
          ),
          itemCount: upcoming.length,
          itemBuilder: (context, index) {
            final session = upcoming[index];
            final diff = session.endTime.difference(session.startTime).inMinutes;
            return InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => StudentAssignmentsScreen(sessionId: session.id, subjectName: session.subjectName)
                ));
              },
              child: UpcomingClassItem(
                subject: session.subjectName,
                teacher: session.teacherName,
                time: intl.DateFormat('hh:mm a').format(session.startTime),
                duration: "$diff دقيقة",
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(height: 150, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
            const SizedBox(height: 20),
            Row(children: List.generate(2, (i) => Expanded(child: Container(height: 100, margin: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))))),
            const SizedBox(height: 30),
            Container(height: 20, width: 150, color: Colors.white),
            const SizedBox(height: 20),
            ...List.generate(3, (i) => Container(height: 80, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
          ],
        ),
      ),
    );
  }
}
