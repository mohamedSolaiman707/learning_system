import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/models/session_model.dart';
import '../widgets/next_class_card.dart';
import '../widgets/upcoming_class_item.dart';
import '../../video_room/video_room_screen.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  final supabase = Supabase.instance.client;
  late Future<List<SessionModel>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _fetchSessions();
  }

  Future<List<SessionModel>> _fetchSessions() async {
    final userId = supabase.auth.currentUser!.id;
    final response = await supabase
        .from('sessions')
        .select('*, profiles:teacher_id(full_name), enrollments!inner(student_id)')
        .eq('enrollments.student_id', userId)
        .order('start_time', ascending: true);

    return (response as List).map((data) => SessionModel.fromMap(data)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? "أحمد";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: _buildAppBar(),
      body: FutureBuilder<List<SessionModel>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingSkeleton();
          }

          final sessions = snapshot.data ?? [];
          final nextSession = sessions.isNotEmpty ? sessions.first : null;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _sessionsFuture = _fetchSessions();
              });
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(userName),
                  const SizedBox(height: 20),
                  
                  if (nextSession != null)
                    _buildAnimatedCard(
                      child: NextClassCard(
                        subject: nextSession.subjectName,
                        teacher: nextSession.teacherName,
                        startTime: DateFormat('hh:mm a').format(nextSession.startTime),
                        isLive: nextSession.isLive,
                        onJoin: () => _navigateToVideoRoom(nextSession, userName),
                      ),
                    )
                  else
                    _buildEmptyState(),

                  const SizedBox(height: 30),
                  _buildSectionTitle("إحصائياتي"),
                  const SizedBox(height: 16),
                  _buildStatsGrid(),
                  
                  const SizedBox(height: 30),
                  _buildSectionTitle("حصص اليوم"),
                  const SizedBox(height: 12),
                  
                  ...sessions.map((session) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: UpcomingClassItem(
                      subject: session.subjectName,
                      teacher: session.teacherName,
                      time: DateFormat('hh:mm a').format(session.startTime),
                      duration: "${session.endTime.difference(session.startTime).inMinutes} دقيقة",
                    ),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text("EduConnect Pro"),
      actions: [
        Stack(
          children: [
            IconButton(onPressed: () {}, icon: const Icon(IconlyLight.notification)),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: Colors.red, border: Border.all(color: Colors.white, width: 2), shape: BoxShape.circle),
              ),
            )
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "مرحباً بك، 👋",
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        Text(
          name,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
        ),
        TextButton(onPressed: () {}, child: const Text("مشاهدة الكل")),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(child: _buildProgressCard("الحضور", 0.85, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildProgressCard("المهام", 0.60, Colors.orange)),
      ],
    );
  }

  Widget _buildProgressCard(String title, double percent, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          CircularPercentIndicator(
            radius: 45.0,
            lineWidth: 8.0,
            percent: percent,
            center: Text("${(percent * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            progressColor: color,
            backgroundColor: color.withOpacity(0.1),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 1500,
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.blue.withOpacity(0.1))),
      child: const Column(
        children: [
          Icon(IconlyLight.calendar, size: 50, color: Colors.blue),
          SizedBox(height: 16),
          Text("لا توجد حصص مجدولة الآن", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text("استرخِ قليلاً، سنخبرك عند إضافة دروس جديدة", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard({required Widget child}) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, double value, child) {
        return Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child));
      },
      child: child,
    );
  }

  void _navigateToVideoRoom(SessionModel session, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoRoomScreen(
          title: "حصة ${session.subjectName}",
          roomName: "room_${session.id}",
          userName: userName,
        ),
      ),
    );
  }
}
