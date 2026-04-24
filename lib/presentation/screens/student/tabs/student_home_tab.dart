import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart';
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

    // جلب الحصص التي سجل فيها الطالب
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
      appBar: AppBar(
        title: const Text("الرئيسية"),
        actions: [
          IconButton(
            onPressed: () => supabase.auth.signOut(),
            icon: const Icon(IconlyLight.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<SessionModel>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("حدث خطأ: ${snapshot.error}"));
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
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "مرحباً، $userName",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  if (nextSession != null)
                    NextClassCard(
                      subject: nextSession.subjectName,
                      teacher: nextSession.teacherName,
                      startTime: DateFormat('hh:mm a').format(nextSession.startTime),
                      isLive: nextSession.isLive,
                      onJoin: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoRoomScreen(
                              title: "حصة ${nextSession.subjectName}",
                              roomName: "room_${nextSession.id}",
                              userName: userName,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("لا توجد حصص مجدولة قريباً"),
                      ),
                    ),

                  const SizedBox(height: 24),
                  const Text(
                    "إحصائياتي",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildStatsRow(),
                  
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "حصص اليوم",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(onPressed: () {}, child: const Text("الكل")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return UpcomingClassItem(
                        subject: session.subjectName,
                        teacher: session.teacherName,
                        time: DateFormat('hh:mm a').format(session.startTime),
                        duration: "${session.endTime.difference(session.startTime).inMinutes} دقيقة",
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildProgressCard(
            context,
            title: "الحضور",
            percent: 0.85,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildProgressCard(
            context,
            title: "الواجبات",
            percent: 0.60,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(BuildContext context, {required String title, required double percent, required Color color}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircularPercentIndicator(
              radius: 40.0,
              lineWidth: 8.0,
              percent: percent,
              center: Text("${(percent * 100).toInt()}%"),
              progressColor: color,
              backgroundColor: color.withOpacity(0.1),
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
