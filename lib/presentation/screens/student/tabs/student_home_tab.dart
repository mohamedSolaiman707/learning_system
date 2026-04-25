import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/next_class_card.dart';
import '../widgets/upcoming_class_item.dart';
import '../../video_room/video_room_screen.dart';
import '../../../core/models/session_model.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  final supabase = Supabase.instance.client;
  bool _isJoining = false;
  List<SessionModel> _sessions = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // تحديث الواجهة كل 10 ثوانٍ لضمان اختفاء الحصص المنتهية فوراً
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) _filterAndRefreshLocal();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      
      final response = await supabase
          .from('enrollments')
          .select('sessions(*, profiles:teacher_id(full_name), rooms(is_active))')
          .eq('student_id', userId);

      final List<dynamic> data = response as List;
      
      final List<SessionModel> loadedSessions = data.map((item) {
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
      }).toList();

      if (mounted) {
        setState(() {
          _sessions = loadedSessions;
          _isLoading = false;
          _filterAndRefreshLocal(); // فلترة فورية بعد التحميل
        });
      }
    } catch (e) {
      debugPrint("Error fetching sessions: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // فلترة الحصص المنتهية بناءً على توقيت الجهاز الحالي
  void _filterAndRefreshLocal() {
    final now = DateTime.now();
    setState(() {
      _sessions = _sessions.where((s) => s.endTime.isAfter(now)).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
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
            decoration: const InputDecoration(hintText: "أدخل كود المادة", prefixIcon: Icon(IconlyLight.password)),
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: result['success'] ? Colors.green : Colors.orange));
                  if (result['success']) _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red));
                } finally {
                  setDialogState(() => _isJoining = false);
                }
              },
              child: const Text("انضمام"),
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
    
    // جلب أول حصة لم تنتهِ بعد
    final nextSession = _sessions.isNotEmpty ? _sessions.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("EduConnect Pro", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _showJoinCodeDialog, icon: const Icon(Icons.add_box_rounded, color: Colors.blue, size: 28)),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading && _sessions.isEmpty
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: () => _loadData(),
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
                    const Text("حصص اليوم القادمة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_sessions.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text("لا توجد حصص، انضم عبر كود الآن", style: TextStyle(color: Colors.grey))))
                    else
                      ..._sessions.map((s) {
                        final duration = s.endTime.difference(s.startTime).inMinutes;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: UpcomingClassItem(
                            subject: s.subjectName,
                            teacher: s.teacherName,
                            time: DateFormat('hh:mm a').format(s.startTime),
                            duration: "$duration دقيقة",
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  void _navigateToVideoRoom(SessionModel session, String userName) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => VideoRoomScreen(title: "بث مباشر: ${session.subjectName}", roomName: "room_${session.id}", userName: userName)));
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100, child: ListView.builder(padding: const EdgeInsets.all(20), itemCount: 3, itemBuilder: (_, __) => Container(height: 100, margin: const EdgeInsets.bottom(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))));
  }

  Widget _buildEmptyState() {
    return Container(width: double.infinity, padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(24)), child: const Column(children: [Icon(IconlyLight.calendar, size: 50, color: Colors.blue), SizedBox(height: 16), Text("لا توجد حصص مجدولة الآن", style: TextStyle(fontWeight: FontWeight.bold))]));
  }

  Widget _buildAnimatedCard({required Widget child}) {
    return TweenAnimationBuilder(tween: Tween<double>(begin: 0, end: 1), duration: const Duration(milliseconds: 600), builder: (context, double value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child)), child: child);
  }
}
