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
  bool _isJoining = false;

  // جلب البيانات مع التحقق من حالة الـ "لايف" لكل حصة
  Future<List<SessionModel>> _fetchSessionsData() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      
      // جلب الحصص المرتبطة بالطالب مع حالة الغرفة النشطة
      final response = await supabase
          .from('enrollments')
          .select('sessions(*, profiles:teacher_id(full_name), rooms(is_active))')
          .eq('student_id', userId);

      final List<dynamic> data = response as List;
      
      return data.map((item) {
        final sessionData = item['sessions'];
        final rooms = sessionData['rooms'] as List?;
        // الحصة تكون Live إذا وجد سجل في جدول rooms وحالته active
        final bool isLiveNow = rooms != null && rooms.any((r) => r['is_active'] == true);
        
        final session = SessionModel.fromMap(sessionData);
        return SessionModel(
          id: session.id,
          subjectName: session.subjectName,
          teacherName: session.teacherName,
          startTime: session.startTime,
          endTime: session.endTime,
          isLive: isLiveNow,
        );
      }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
    } catch (e) {
      debugPrint("Error: $e");
      return [];
    }
  }

  void _showJoinCodeDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("انضم لمادة جديدة"),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(hintText: "أدخل كود المادة", prefixIcon: Icon(IconlyLight.password)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.isEmpty) return;
              final result = await supabase.rpc('enroll_student_by_code', params: {'p_code': codeController.text.toUpperCase()});
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
              setState(() {}); // تحديث الصفحة لرؤية المادة الجديدة
            },
            child: const Text("انضمام"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? "الطالب";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("EduConnect Pro", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _showJoinCodeDialog, icon: const Icon(Icons.add_box_rounded, color: Colors.blue)),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder(
        // السر هنا: الاستماع لجدول الغرف لحظة بلحظة
        stream: supabase.from('rooms').stream(primaryKey: ['id']),
        builder: (context, _) {
          return FutureBuilder<List<SessionModel>>(
            future: _fetchSessionsData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final sessions = snapshot.data ?? [];
              final nextSession = sessions.isNotEmpty ? sessions.first : null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("مرحباً بك، 👋", style: TextStyle(color: Colors.grey.shade600)),
                    Text(userName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    
                    if (nextSession != null)
                      NextClassCard(
                        subject: nextSession.subjectName,
                        teacher: nextSession.teacherName,
                        startTime: DateFormat('hh:mm a').format(nextSession.startTime),
                        isLive: nextSession.isLive, // ستصبح true فوراً عند بدء المدرس
                        onJoin: () => _navigateToVideoRoom(nextSession, userName),
                      )
                    else
                      const Center(child: Text("لا توجد حصص مسجلة")),

                    const SizedBox(height: 30),
                    const Text("حصصك القادمة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...sessions.map((s) => UpcomingClassItem(
                      subject: s.subjectName,
                      teacher: s.teacherName,
                      time: DateFormat('hh:mm a').format(s.startTime),
                      duration: "60 دقيقة",
                    )),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _navigateToVideoRoom(SessionModel session, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoRoomScreen(
          title: "بث مباشر: ${session.subjectName}",
          roomName: "room_${session.id}",
          userName: userName,
        ),
      ),
    );
  }
}
