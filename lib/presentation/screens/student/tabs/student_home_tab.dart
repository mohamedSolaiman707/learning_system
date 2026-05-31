import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shimmer/shimmer.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/assignments_service.dart';
import '../../../../core/models/session_model.dart';
import '../widgets/next_class_card.dart';
import '../widgets/upcoming_class_item.dart';
import '../../video_room/video_room_screen.dart';
import '../../video_room/waiting_room_screen.dart';
import '../assignments/student_assignments_screen.dart';
import '../resources/student_resources_screen.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<SessionModel> _enrolledSessions = [];
  List<SessionModel> _allActiveSessions = [];
  SessionModel? _nextSession;
  int _pendingAssignmentsCount = 0;
  int _completedAssignmentsCount = 0;
  Timer? _refreshTimer;
  late AnimationController _liveController;

  @override
  void initState() {
    super.initState();
    _liveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _loadStudentData(initial: true);
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadStudentData(initial: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _liveController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData({bool initial = true}) async {
    if (!mounted) return;
    if (initial) setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      final assignService = AssignmentsService();
      
      if (auth.user != null) {
        final enrolledResponse = await db.getStudentSchedule(auth.user!.id);
        final activeResponse = await db.getActiveSessions();

        if (mounted) {
          setState(() {
            final now = DateTime.now();
            _enrolledSessions = enrolledResponse
                .map((e) => SessionModel.fromMap(e['sessions']))
                .where((s) => s.endTime.isAfter(now)) 
                .toList();
            
            _enrolledSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
            _allActiveSessions = activeResponse.map((e) => SessionModel.fromMap(e)).toList();

            try {
              _nextSession = _enrolledSessions.firstWhere(
                (s) => (s.isLive || s.isActive) && s.endTime.isAfter(now),
                orElse: () => _enrolledSessions.firstWhere((s) => s.endTime.isAfter(now)),
              );
            } catch (_) {
              _nextSession = null;
            }
            
            if (initial) _isLoading = false;
          });

          int pending = 0;
          int completed = 0;
          for (var session in _enrolledSessions) {
             final assignments = await assignService.getAssignments(session.id);
             for (var assignment in assignments) {
               final submission = await assignService.getStudentSubmission(assignment.id, auth.user!.id);
               if (submission == null) {
                 pending++;
               } else {
                 completed++;
               }
             }
          }
          if (mounted) setState(() {
            _pendingAssignmentsCount = pending;
            _completedAssignmentsCount = completed;
          });
        }
      }
    } catch (e) {
      if (mounted && initial) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinActiveSession(SessionModel session) async {
    HapticFeedback.mediumImpact();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    await db.enrollStudentBySessionId(auth.user!.id, session.id);
    
    if (!mounted) return;

    if (session.status == 'waiting') {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => WaitingRoomScreen(
          session: session,
          userName: auth.profile?['full_name'] ?? "الطالب",
          userId: auth.user!.id,
        ),
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => VideoRoomScreen(
          title: session.subjectName,
          roomName: "room_${session.id}",
          userName: auth.profile?['full_name'] ?? "الطالب",
          userId: auth.user!.id,
          isTeacher: false,
          sessionId: session.id,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.profile?['full_name'] ?? "الطالب";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading 
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: () => _loadStudentData(initial: true),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(userName),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(Responsive.isMobile(context) ? 20 : 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEnhancedWelcome(userName),
                          const SizedBox(height: 32),
                          
                          if (_allActiveSessions.isNotEmpty) ...[
                            _buildSectionHeader("بث مباشر الآن", isLive: true),
                            const SizedBox(height: 16),
                            _buildLiveSessionsCarousel(),
                            const SizedBox(height: 32),
                          ],

                          _buildSectionHeader("خطتك الدراسية"),
                          const SizedBox(height: 16),
                          _buildProgressOverview(),
                          const SizedBox(height: 32),

                          if (_nextSession != null) ...[
                            _buildSectionHeader("الحصة القادمة"),
                            const SizedBox(height: 16),
                            _buildNextClassCard(userName),
                            const SizedBox(height: 32),
                          ],
                          
                          if (_enrolledSessions.isNotEmpty) ...[
                            _buildSectionHeader("جدول الحصص"),
                            const SizedBox(height: 16),
                            _buildUpcomingGrid(),
                          ],
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
      expandedHeight: 100, pinned: true, elevation: 0,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        title: Text("الرئيسية", style: TextStyle(color: Colors.black.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      actions: [
        IconButton(onPressed: () {}, icon: const Badge(child: Icon(Icons.notifications_none_rounded, color: Colors.black87))),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Hero(
            tag: 'profile_pic',
            child: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : "U", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedWelcome(String name) {
    final hour = DateTime.now().hour;
    String greeting = "صباح الخير";
    if (hour >= 12 && hour < 17) greeting = "طاب يومك";
    else if (hour >= 17) greeting = "مساء الخير";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$greeting، $name 👋", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
        const SizedBox(height: 4),
        Text(
          _enrolledSessions.isEmpty ? "ليس لديك حصص اليوم، استمتع بوقتك!" : "لديك ${_enrolledSessions.length} حصص متبقية اليوم. بالتوفيق!",
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {bool isLive = false}) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
        if (isLive) ...[
          const SizedBox(width: 10),
          FadeTransition(
            opacity: _liveController,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
              child: const Text("LIVE", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildLiveSessionsCarousel() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _allActiveSessions.length,
        itemBuilder: (context, index) {
          final session = _allActiveSessions[index];
          return Container(
            width: 300,
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6200EE), Color(0xFFBB86FC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: const Color(0xFF6200EE).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.subjectName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text("أ. ${session.teacherName}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _joinActiveSession(session),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6200EE),
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text("انضمام الآن", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressOverview() {
    double progress = 0;
    if ((_pendingAssignmentsCount + _completedAssignmentsCount) > 0) {
      progress = _completedAssignmentsCount / (_pendingAssignmentsCount + _completedAssignmentsCount);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 70, width: 70,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.blue.shade50,
                  color: Colors.blue.shade600,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("إكمال الواجبات", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text("لقد أنجزت $_completedAssignmentsCount من أصل ${_pendingAssignmentsCount + _completedAssignmentsCount} واجبات متبقية.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextClassCard(String userName) {
    return GestureDetector(
      onTap: () => _showSessionOptions(_nextSession!),
      child: NextClassCard(
        subject: _nextSession!.subjectName,
        teacher: _nextSession!.teacherName,
        startTime: intl.DateFormat('hh:mm a').format(_nextSession!.startTime),
        isLive: _nextSession!.isLive || _nextSession!.isActive,
        onJoin: () => _joinActiveSession(_nextSession!),
      ),
    );
  }

  void _showSessionOptions(SessionModel session) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text(session.subjectName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("أ. ${session.teacherName}", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            _buildOptionTile(Icons.assignment_outlined, "عرض الواجبات", Colors.blue, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => StudentAssignmentsScreen(sessionId: session.id, subjectName: session.subjectName)));
            }),
            const SizedBox(height: 12),
            _buildOptionTile(Icons.folder_open_rounded, "المكتبة والمصادر", Colors.orange, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => StudentResourcesScreen(sessionId: session.id, subjectName: session.subjectName)));
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingGrid() {
    final upcoming = _enrolledSessions.where((s) => s.id != _nextSession?.id).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.isMobile(context) ? 1 : 2,
        crossAxisSpacing: 16, mainAxisSpacing: 16, mainAxisExtent: 100,
      ),
      itemCount: upcoming.length,
      itemBuilder: (context, index) {
        final session = upcoming[index];
        return InkWell(
          onTap: () => _showSessionOptions(session),
          child: UpcomingClassItem(
            subject: session.subjectName,
            teacher: session.teacherName,
            time: intl.DateFormat('hh:mm a').format(session.startTime),
            duration: "${session.endTime.difference(session.startTime).inMinutes} دقيقة",
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200, highlightColor: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(height: 30, width: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 32),
            Container(height: 180, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32))),
            const SizedBox(height: 32),
            Container(height: 100, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32))),
            const SizedBox(height: 32),
            ...List.generate(3, (i) => Container(height: 80, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)))),
          ],
        ),
      ),
    );
  }
}
