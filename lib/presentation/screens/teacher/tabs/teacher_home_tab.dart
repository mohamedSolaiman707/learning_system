import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/session_model.dart';
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
  bool _isLoading = true;
  List<SessionModel> _todaySessions = [];
  int _totalStudents = 0;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);
    try {
      final teacherId = supabase.auth.currentUser!.id;
      final today = DateTime.now().toIso8601String().split('T')[0];

      // 1. جلب حصص اليوم
      final sessionsResponse = await supabase
          .from('sessions')
          .select('*, profiles:teacher_id(full_name)')
          .eq('teacher_id', teacherId)
          .gte('start_time', '${today}T00:00:00')
          .lte('start_time', '${today}T23:59:59')
          .order('start_time', ascending: true);

      final List<dynamic> sessionsData = sessionsResponse as List;
      
      // 2. حساب إجمالي الطلاب المسجلين في حصص اليوم
      if (sessionsData.isNotEmpty) {
        // تصحيح: استخدام inFilter بدلاً من in_
        final enrollmentsRes = await supabase
            .from('enrollments')
            .select()
            .inFilter('session_id', sessionsData.map((s) => s['id']).toList())
            .count(CountOption.exact);
        
        setState(() {
          _totalStudents = enrollmentsRes.count;
        });
      }

      setState(() {
        _todaySessions = sessionsData.map((s) => SessionModel.fromMap(s)).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading teacher data: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = _todaySessions.isNotEmpty ? _todaySessions.first : null;
    final teacherName = supabase.auth.currentUser?.userMetadata?['full_name'] ?? "المدرس";

    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة المدرس"),
        actions: [
          IconButton(
            onPressed: () => supabase.auth.signOut().then((_) => Navigator.pushReplacementNamed(context, '/login')),
            icon: const Icon(IconlyLight.logout),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeacherData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "مرحباً، أ. $teacherName",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TeacherStatCard(
                            title: "طلاب اليوم",
                            value: _totalStudents.toString(),
                            icon: IconlyLight.user_1,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TeacherStatCard(
                            title: "حصص اليوم",
                            value: _todaySessions.length.toString(),
                            icon: IconlyLight.video,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (currentSession != null)
                      _buildCurrentSessionCard(currentSession)
                    else
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("لا توجد حصص مجدولة لليوم"),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      "إجراءات سريعة",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(IconlyLight.user, color: Colors.orange),
                      title: const Text("تسجيل الحضور"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        if (currentSession != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AttendanceScreen(
                                sessionId: currentSession.id,
                                subjectName: currentSession.subjectName,
                              ),
                            ),
                          );
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentSessionCard(SessionModel session) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(IconlyLight.video, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "الحصة القادمة/الحالية",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    Text(
                      session.subjectName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${DateFormat('hh:mm a').format(session.startTime)} - ${DateFormat('hh:mm a').format(session.endTime)}",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoRoomScreen(
                    title: "بث: ${session.subjectName}",
                    roomName: "room_${session.id}",
                    userName: "Teacher_${session.teacherName}",
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text("بدء البث الآن"),
          ),
        ],
      ),
    );
  }
}
