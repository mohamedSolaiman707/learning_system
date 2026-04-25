import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
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
    if (!mounted) return;
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
        final List<String> sessionIds = sessionsData.map((s) => s['id'].toString()).toList();
        final enrollmentsRes = await supabase
            .from('enrollments')
            .select()
            .inFilter('session_id', sessionIds)
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStartSession(SessionModel session) async {
    setState(() => _isLoading = true);
    try {
      await supabase.rpc('start_teacher_session', params: {
        'p_session_id': session.id,
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoRoomScreen(
            title: "بث مباشر: ${session.subjectName}",
            roomName: "room_${session.id}",
            userName: "Teacher_${session.teacherName}",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ في بدء الحصة: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = _todaySessions.isNotEmpty ? _todaySessions.first : null;
    final teacherName = supabase.auth.currentUser?.userMetadata?['full_name'] ?? "المدرس";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: _buildAppBar(),
      body: _isLoading && _todaySessions.isEmpty
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _loadTeacherData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(teacherName),
                    const SizedBox(height: 24),
                    _buildStatsRow(),
                    const SizedBox(height: 32),
                    const Text("الحصة القادمة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (currentSession != null)
                      _buildAnimatedCard(
                        child: _buildCurrentSessionCard(currentSession),
                      )
                    else
                      _buildEmptyState(),
                    const SizedBox(height: 32),
                    const Text("إجراءات سريعة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildQuickActions(currentSession),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text("لوحة المدرس"),
      actions: [
        IconButton(
          onPressed: () => supabase.auth.signOut().then((_) => Navigator.pushReplacementNamed(context, '/login')),
          icon: const Icon(IconlyLight.logout),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("أهلاً بك، 👋", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
        Text("أ. $name", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: TeacherStatCard(
            title: "إجمالي الطلاب",
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
    );
  }

  Widget _buildCurrentSessionCard(SessionModel session) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade500]),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(IconlyLight.video, color: Colors.white, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.subjectName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("${DateFormat('hh:mm a').format(session.startTime)} - ${DateFormat('hh:mm a').format(session.endTime)}", style: TextStyle(color: Colors.white.withOpacity(0.8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _handleStartSession(session),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue.shade700),
            child: const Text("بدء البث المباشر الآن"),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(SessionModel? currentSession) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: ListTile(
        leading: const Icon(IconlyLight.user, color: Colors.orange),
        title: const Text("تسجيل الحضور والغياب", style: TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          if (currentSession != null) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen(sessionId: currentSession.id, subjectName: currentSession.subjectName)));
          }
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text("لا توجد حصص مجدولة"));
  }

  Widget _buildAnimatedCard({required Widget child}) {
    return child;
  }
}
