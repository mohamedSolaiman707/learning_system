import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shimmer/shimmer.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/models/session_model.dart';
import '../widgets/teacher_stat_card.dart';
import '../attendance/attendance_screen.dart';
import '../assignments/teacher_assignments_screen.dart'; 
import '../../video_room/video_room_screen.dart';

class TeacherHomeTab extends StatefulWidget {
  const TeacherHomeTab({super.key});

  @override
  State<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends State<TeacherHomeTab> {
  bool _isLoading = true;
  List<SessionModel> _sessions = [];
  SessionModel? _nextSession;
  int _totalStudents = 0; // حقل جديد لعدد الطلاب

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      
      if (auth.user != null) {
        // جلب الحصص والإحصائيات معاً
        final results = await Future.wait([
          db.getTeacherSessions(auth.user!.id),
          db.getTeacherStats(auth.user!.id),
        ]);

        if (mounted) {
          setState(() {
            _sessions = (results[0] as List).map((e) => SessionModel.fromMap(e)).toList();
            _totalStudents = (results[1] as Map<String, dynamic>)['totalStudents'] ?? 0;
            
            final now = DateTime.now();
            if (_sessions.isNotEmpty) {
               try {
                 // البحث عن الحصة القادمة التي لم تنتهِ بعد
                 _nextSession = _sessions.firstWhere((s) => s.endTime.isAfter(now));
               } catch (_) {
                 _nextSession = _sessions.last;
               }
            } else {
              _nextSession = null;
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleQuickAction(String type) {
    if (_sessions.isEmpty) {
      _showNoSessionAlert();
      return;
    }
    if (_sessions.length == 1) {
      _navigateToActionScreen(type, _sessions.first);
    } else {
      _showSessionPicker(type);
    }
  }

  void _showSessionPicker(String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type == 'attendance' ? "اختر حصة للتحضير" : "اختر حصة لإضافة واجب", 
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final s = _sessions[index];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(IconlyLight.video, color: Colors.blue)),
                    title: Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(intl.DateFormat('hh:mm a').format(s.startTime)),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToActionScreen(type, s);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToActionScreen(String type, SessionModel session) {
    if (type == 'attendance') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen(sessionId: session.id, subjectName: session.subjectName)));
    } else if (type == 'assignment') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => TeacherAssignmentsScreen(sessionId: session.id, subjectName: session.subjectName)));
    }
  }

  Future<void> _startLive(SessionModel session, String teacherName) async {
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      await db.toggleRoomStatus(session.id, true);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => VideoRoomScreen(title: session.subjectName, roomName: "room_${session.id}", userName: "أ. $teacherName")
      )).then((_) => _showEndLiveDialog(session.id));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل بدء البث المباشر")));
    }
  }

  void _showEndLiveDialog(String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إنهاء البث"),
        content: const Text("هل انتهت الحصة وتريد إغلاق البث للطلاب؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("لا، سأعود")),
          ElevatedButton(
            onPressed: () async {
              final db = Provider.of<DatabaseService>(context, listen: false);
              await db.toggleRoomStatus(sessionId, false);
              if (mounted) { Navigator.pop(context); _loadData(); }
            },
            child: const Text("نعم، إنهاء الحصة"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final name = authProvider.profile?['full_name'] ?? "المدرس";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading 
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(name),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(Responsive.isMobile(context) ? 16 : 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeHeader(name),
                          const SizedBox(height: 24),
                          _buildStatsSection(),
                          const SizedBox(height: 32),
                          Responsive(
                            mobile: Column(children: [_buildCurrentSessionSection(name), const SizedBox(height: 32), _buildQuickActions()]),
                            desktop: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(flex: 3, child: _buildCurrentSessionSection(name)),
                              const SizedBox(width: 30),
                              Expanded(flex: 2, child: _buildQuickActions()),
                            ]),
                          ),
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
      expandedHeight: 100, floating: true, pinned: true,
      backgroundColor: Colors.white, elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text("لوحة المدرس", style: TextStyle(color: Colors.black.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
      ),
      actions: [IconButton(onPressed: () {}, icon: const Badge(child: Icon(IconlyLight.notification))), const SizedBox(width: 15)],
    );
  }

  Widget _buildWelcomeHeader(String name) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("أهلاً بك، 👋", style: TextStyle(fontSize: 16, color: Colors.grey)),
      Text("أ. $name", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(child: TeacherStatCard(title: "طلابك", value: _totalStudents.toString(), icon: IconlyLight.user_1, color: Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: TeacherStatCard(title: "حصص اليوم", value: _sessions.length.toString(), icon: IconlyLight.video, color: Colors.orange)),
        if (Responsive.isDesktop(context)) ...[
          const SizedBox(width: 16),
          const Expanded(child: TeacherStatCard(title: "التقييم", value: "5.0", icon: IconlyLight.star, color: Colors.amber)),
        ]
      ],
    );
  }

  Widget _buildCurrentSessionSection(String teacherName) {
    if (_nextSession == null) {
      return const Card(
        margin: EdgeInsets.only(top: 16),
        child: Padding(padding: EdgeInsets.all(40), child: Center(child: Text("لا توجد حصص مسجلة لك اليوم", style: TextStyle(color: Colors.grey, fontSize: 16)))),
      );
    }
    final startTime = intl.DateFormat('hh:mm a').format(_nextSession!.startTime);
    final endTime = intl.DateFormat('hh:mm a').format(_nextSession!.endTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("الحصة القادمة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0061FF), Color(0xFF00C6FF)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)), child: const Icon(IconlyLight.video, color: Colors.white, size: 30)),
                  const SizedBox(width: 20),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_nextSession!.subjectName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text("اليوم | $startTime - $endTime", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ])),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _startLive(_nextSession!, teacherName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: Colors.blue, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text("ابدأ البث المباشر الآن", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("إجراءات سريعة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildActionCard(IconlyLight.user_1, "تحضير الطلاب", Colors.orange, () => _handleQuickAction('attendance')),
        const SizedBox(height: 12),
        _buildActionCard(IconlyLight.document, "إضافة واجب", Colors.green, () => _handleQuickAction('assignment')),
        const SizedBox(height: 12),
        _buildActionCard(IconlyLight.folder, "المكتبة التعليمية", Colors.blue, () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("قريباً: شاشة المكتبة التعليمية تحت التطوير")));
        }),
      ],
    );
  }

  void _showNoSessionAlert() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا توجد حصص مسجلة لك اليوم للقيام بهذا الإجراء")));
  }

  Widget _buildActionCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: ListTile(
        onTap: onTap,
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
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
            Row(children: List.generate(2, (i) => Expanded(child: Container(height: 100, margin: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))))),
            const SizedBox(height: 30),
            ...List.generate(3, (i) => Container(height: 70, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
          ],
        ),
      ),
    );
  }
}
