import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/utils/responsive.dart';
import '../assignments/teacher_assignments_screen.dart';
import '../attendance/attendance_screen.dart';
import '../resources/teacher_resources_screen.dart';
import '../../video_room/video_room_screen.dart';
import '../widgets/teacher_stat_card.dart';

class TeacherHomeTab extends StatefulWidget {
  const TeacherHomeTab({super.key});

  @override
  State<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends State<TeacherHomeTab> {
  bool _isLoading = true;
  List<SessionModel> _sessions = [];
  SessionModel? _nextSession;
  int _totalStudents = 0;

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
        final results = await Future.wait([
          db.getTeacherSessions(auth.user!.id),
          db.getTeacherStats(auth.user!.id),
        ]);

        if (mounted) {
          setState(() {
            _sessions = (results[0] as List).map((e) => SessionModel.fromMap(e)).toList();
            _totalStudents = (results[1] as Map<String, dynamic>)['totalStudents'] ?? 0;

            final now = DateTime.now();
            final activeSessions = _sessions.where((s) => s.endTime.isAfter(now)).toList();

            if (activeSessions.isNotEmpty) {
              _nextSession = activeSessions.first;
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

  void _showNoSessionAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("لا توجد حصص مسجلة لديك حالياً"))
    );
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
            Text(
              type == 'attendance' ? "اختر حصة للتحضير" : 
              type == 'assignment' ? "اختر حصة للواجبات" : "اختر حصة للمكتبة", 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
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
    } else if (type == 'resources') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => TeacherResourcesScreen(sessionId: session.id, subjectName: session.subjectName)));
    }
  }

  Future<void> _startLive(SessionModel session, String teacherName) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.user?.id ?? "";
      final db = Provider.of<DatabaseService>(context, listen: false);
      
      await db.toggleRoomStatus(session.id, true);
      if (!mounted) return;
      
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => VideoRoomScreen(
          title: session.subjectName, 
          roomName: "room_${session.id}", 
          userName: "أ. $teacherName",
          userId: userId, 
          isTeacher: true,
          sessionId: session.id,
        )
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
          ? const Center(child: CircularProgressIndicator())
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(IconlyLight.calendar, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("لا توجد حصص قادمة حالياً", style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.bold)),
            const Text("سيتم إعلامك فور إضافة حصص جديدة", style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }
    final now = DateTime.now();
    final isUpcoming = _nextSession!.startTime.isAfter(now);
    
    final startTimeStr = intl.DateFormat('hh:mm a').format(_nextSession!.startTime);
    final String liveLink = "https://learning-system-cz8hhsedk-real-estat.vercel.app/#/live?sessionId=${_nextSession!.id}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isUpcoming ? "الحصة القادمة" : "بث مباشر الآن 🔴",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isUpcoming ? Colors.black : Colors.red)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: isUpcoming
                ? LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade400])
                : const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFFF5252)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: (isUpcoming ? Colors.blue : Colors.red).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                    child: Icon(isUpcoming ? IconlyLight.calendar : IconlyLight.video, color: Colors.white, size: 30)
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_nextSession!.subjectName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("بدأت في $startTimeStr وتستمر حتى ${intl.DateFormat('hh:mm a').format(_nextSession!.endTime)}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildCopyBadge(
                          label: "كود: ${_nextSession!.classCode}", 
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _nextSession!.classCode));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم نسخ كود الحصة")));
                          }
                        ),
                        const SizedBox(width: 8),
                        _buildCopyBadge(
                          label: "نسخ الرابط 🔗", 
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: liveLink));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم نسخ رابط الحصة المباشر")));
                          }
                        ),
                      ],
                    ),
                  ])),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _startLive(_nextSession!, teacherName),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: isUpcoming ? Colors.blue.shade700 : Colors.red,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: Text(isUpcoming ? "بدء البث المباشر" : "دخول البث المباشر", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCopyBadge({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("إجراءات سريعة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _buildActionCard("التحضير", IconlyLight.user, Colors.blue, 'attendance'),
            _buildActionCard("الواجبات", IconlyLight.document, Colors.orange, 'assignment'),
            _buildActionCard("المكتبة", IconlyLight.folder, Colors.purple, 'resources'),
            _buildActionCard("التقارير", IconlyLight.chart, Colors.green, 'reports'),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, String type) {
    return InkWell(
      onTap: () => _handleQuickAction(type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
