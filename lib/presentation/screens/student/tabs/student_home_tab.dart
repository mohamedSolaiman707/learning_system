import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/models/resource_model.dart';
import '../widgets/next_class_card.dart';
import '../widgets/upcoming_class_item.dart';
import '../assignments/student_assignments_screen.dart';
import '../../video_room/video_room_screen.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  final supabase = Supabase.instance.client;
  bool _isJoining = false;
  List<SessionModel> _sessions = [];
  List<ResourceModel> _resources = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _loadData(showLoading: false);
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
      
      final results = await Future.wait([
        supabase.from('enrollments').select('sessions(*, profiles:teacher_id(full_name), rooms(is_active))').eq('student_id', userId),
        supabase.from('resources').select().order('created_at', ascending: false),
      ]);

      final List<dynamic> sessionData = results[0] as List;
      final List<dynamic> resourceData = results[1] as List;
      
      final List<SessionModel> loadedSessions = sessionData.map((item) {
        final sData = item['sessions'];
        final rooms = sData['rooms'] as List?;
        final bool isLiveNow = rooms != null && rooms.any((r) => r['is_active'] == true);
        final session = SessionModel.fromMap(sData);
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
          _resources = resourceData.map((r) => ResourceModel.fromMap(r)).toList();
          _isLoading = false;
          _filterAndRefreshLocal();
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("انضم عبر كود"),
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
                final result = await supabase.rpc('enroll_student_by_code', params: {'p_code': codeController.text.trim().toUpperCase()});
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: result['success'] ? Colors.green : Colors.orange));
                if (result['success']) _loadData();
                setDialogState(() => _isJoining = false);
              },
              child: const Text("انضم الآن"),
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
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("مرحباً بك، 👋", style: TextStyle(color: Colors.grey.shade600)),
                    Text(userName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    if (nextSession != null) _buildNextSessionSection(nextSession, userName) else _buildEmptyState(),
                    const SizedBox(height: 32),
                    if (_resources.isNotEmpty) ...[
                      const Text("المصادر المرفوعة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _resources.length,
                          itemBuilder: (context, i) => _buildResourceCard(_resources[i]),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    const Text("حصصك القادمة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._sessions.map((s) => UpcomingClassItem(
                      subject: s.subjectName,
                      teacher: s.teacherName,
                      time: DateFormat('hh:mm a').format(s.startTime),
                      duration: "${s.endTime.difference(s.startTime).inMinutes} دقيقة",
                    )),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNextSessionSection(SessionModel nextSession, String userName) {
    return Column(
      children: [
        NextClassCard(
          subject: nextSession.subjectName,
          teacher: nextSession.teacherName,
          startTime: DateFormat('hh:mm a').format(nextSession.startTime),
          isLive: nextSession.isLive,
          onJoin: () => _navigateToVideoRoom(nextSession, userName),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildActionBtn(icon: IconlyLight.document, label: "الواجبات", color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StudentAssignmentsScreen(sessionId: nextSession.id, subjectName: nextSession.subjectName))))),
            const SizedBox(width: 12),
            Expanded(child: _buildActionBtn(icon: IconlyLight.folder, label: "المصادر", color: Colors.blue, onTap: () {})),
          ],
        ),
      ],
    );
  }

  Widget _buildActionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold))])));
  }

  Widget _buildResourceCard(ResourceModel res) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(res.fileUrl)),
      child: Container(width: 150, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(IconlyLight.document, color: Colors.blue), const SizedBox(height: 8), Text(res.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)])),
    );
  }

  void _navigateToVideoRoom(SessionModel session, String userName) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => VideoRoomScreen(title: "بث مباشر: ${session.subjectName}", roomName: "room_${session.id}", userName: userName)));
  }

  Widget _buildEmptyState() => Container(width: double.infinity, padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(24)), child: const Column(children: [Icon(IconlyLight.calendar, size: 50, color: Colors.blue), SizedBox(height: 16), Text("لا توجد حصص مجدولة الآن", style: TextStyle(fontWeight: FontWeight.bold))]));
}
