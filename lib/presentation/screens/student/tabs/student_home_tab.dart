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

  // جلب البيانات بطريقة Stream ليكون التطبيق حياً
  Stream<List<SessionModel>> _getSessionsStream() {
    final userId = supabase.auth.currentUser!.id;
    
    // نستخدم Stream على جدول enrollments لأنه هو الذي يتغير عند الانضمام بكود
    return supabase
        .from('enrollments')
        .stream(primaryKey: ['id'])
        .eq('student_id', userId)
        .asyncMap((event) async {
          // بعد كل تغيير، نجلب تفاصيل الحصص كاملة
          final response = await supabase
              .from('enrollments')
              .select('sessions(*, profiles:teacher_id(full_name), rooms(is_active))')
              .eq('student_id', userId);
          
          final List<dynamic> data = response as List;
          return data.map((item) {
            final sessionData = item['sessions'];
            final rooms = sessionData['rooms'] as List?;
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
        });
  }

  void _showJoinCodeDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("انضم لمادة جديدة"),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              hintText: "أدخل كود المادة",
              prefixIcon: Icon(IconlyLight.password),
              filled: true,
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: _isJoining ? null : () async {
                if (codeController.text.isEmpty) return;
                setDialogState(() => _isJoining = true);
                try {
                  final result = await supabase.rpc('enroll_student_by_code', params: {
                    'p_code': codeController.text.trim().toUpperCase(),
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result['message']),
                    backgroundColor: result['success'] ? Colors.green : Colors.orange,
                  ));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red));
                } finally {
                  setDialogState(() => _isJoining = false);
                }
              },
              child: _isJoining ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("انضمام"),
            ),
          ],
        ),
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
        elevation: 0,
        title: const Text("EduConnect Pro", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _showJoinCodeDialog, icon: const Icon(Icons.add_box_rounded, color: Colors.blue, size: 28)),
          IconButton(onPressed: () {}, icon: const Icon(IconlyLight.notification)),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<SessionModel>>(
        stream: _getSessionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return _buildLoadingSkeleton();

          final sessions = snapshot.data ?? [];
          final nextSession = sessions.where((s) => s.endTime.isAfter(DateTime.now())).firstOrNull;

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
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
                      isLive: nextSession.isLive,
                      onJoin: () => _navigateToVideoRoom(nextSession, userName),
                    )
                  else
                    _buildEmptyState(),

                  const SizedBox(height: 30),
                  const Text("حصصك القادمة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (sessions.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text("لا توجد حصص، انضم عبر كود الآن", style: TextStyle(color: Colors.grey)),
                    ))
                  else
                    ...sessions.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: UpcomingClassItem(
                        subject: s.subjectName,
                        teacher: s.teacherName,
                        time: DateFormat('hh:mm a').format(s.startTime),
                        duration: "60 دقيقة",
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

  void _navigateToVideoRoom(SessionModel session, String userName) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => VideoRoomScreen(title: "بث مباشر: ${session.subjectName}", roomName: "room_${session.id}", userName: userName)));
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100, child: ListView.builder(padding: const EdgeInsets.all(20), itemCount: 3, itemBuilder: (_, __) => Container(height: 100, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))));
  }

  Widget _buildEmptyState() {
    return Container(width: double.infinity, padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(24)), child: const Column(children: [Icon(IconlyLight.calendar, size: 50, color: Colors.blue), SizedBox(height: 16), Text("لا توجد حصص مجدولة الآن", style: TextStyle(fontWeight: FontWeight.bold))]));
  }
}
