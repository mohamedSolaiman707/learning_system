import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shimmer/shimmer.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/models/session_model.dart';
import '../widgets/next_class_card.dart';
import '../widgets/upcoming_class_item.dart';
import '../../video_room/video_room_screen.dart';
import '../../video_room/video_room_controller.dart';
import '../../video_room/waiting_room_screen.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isJoining = false; 
  List<SessionModel> _enrolledSessions = [];
  List<SessionModel> _allActiveSessions = [];
  SessionModel? _nextSession;
  Timer? _refreshTimer;
  late AnimationController _liveController;

  // Real Statistics Data
  Map<String, dynamic> _stats = {
    'learningHours': '0.0',
    'points': 0,
    'completedSessions': 0,
  };

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
      
      if (auth.user != null) {
        // Fetch real data from DB
        final enrolledResponse = await db.getStudentSchedule(auth.user!.id);
        final activeResponse = await db.getActiveSessions();
        final statsResponse = await db.getStudentStats(auth.user!.id);

        if (mounted) {
          final now = DateTime.now();
          final List<SessionModel> tempEnrolled = enrolledResponse
                .map((e) => SessionModel.fromMap(e['sessions']))
                .where((s) => s.endTime.isAfter(now)) 
                .toList();
            
          tempEnrolled.sort((a, b) => a.startTime.compareTo(b.startTime));
          final List<SessionModel> tempActive = activeResponse.map((e) => SessionModel.fromMap(e)).toList();

          SessionModel? tempNext;
          try {
            tempNext = tempEnrolled.firstWhere(
              (s) => (s.isLive || s.isActive) && s.endTime.isAfter(now),
              orElse: () => tempEnrolled.firstWhere((s) => s.endTime.isAfter(now)),
            );
          } catch (_) {
            tempNext = null;
          }

          setState(() {
            _enrolledSessions = tempEnrolled;
            _allActiveSessions = tempActive;
            _nextSession = tempNext;
            _stats = statsResponse; // Update real stats
            if (initial) _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && initial) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinActiveSession(SessionModel session) async {
    if (_isJoining) return;
    
    setState(() => _isJoining = true);
    HapticFeedback.mediumImpact();

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      
      bool isKicked = false;
      try {
        isKicked = await db.isStudentKicked(session.id, auth.user!.id)
            .timeout(const Duration(seconds: 1));
      } catch (e) {
        isKicked = false;
      }

      if (isKicked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("عذراً، لا يمكنك دخول هذه الحصة بسبب طردك مسبقاً 🚫"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isJoining = false);
        return;
      }

      db.enrollStudentBySessionId(auth.user!.id, session.id).catchError((e) => debugPrint("Silent error: $e"));

      if (!mounted) return;

      final String userName = auth.profile?['full_name'] ?? "الطالب";
      final String userId = auth.user!.id;

      if (session.status == 'waiting') {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => WaitingRoomScreen(session: session, userName: userName, userId: userId),
        ));
      } else {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (_) => VideoRoomController(
              title: session.subjectName,
              roomName: "room_${session.id}",
              userName: userName,
              userId: userId,
              isTeacher: false,
              sessionId: session.id,
            ),
            child: VideoRoomScreen(
              title: session.subjectName,
              roomName: "room_${session.id}",
              userName: userName,
              userId: userId,
              isTeacher: false,
              sessionId: session.id,
            ),
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("يرجى المحاولة مرة أخرى"), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _isJoining = false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.profile?['full_name'] ?? "الطالب";
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Stack(
        children: [
          _isLoading 
              ? _buildLoadingSkeleton()
              : RefreshIndicator(
                  color: const Color(0xFF102A43),
                  onRefresh: () => _loadStudentData(initial: true),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      _buildSliverAppBar(userName),
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 40 : 20,
                                vertical: 20
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildEnhancedWelcome(userName),
                                  const SizedBox(height: 40),
                                  
                                  if (_allActiveSessions.isNotEmpty) ...[
                                    _buildSectionHeader("البث المباشر المتاح", isLive: true),
                                    const SizedBox(height: 20),
                                    _buildLiveSessionsCarousel(),
                                    const SizedBox(height: 40),
                                  ],

                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (_nextSession != null) ...[
                                              _buildSectionHeader("الحصة القادمة"),
                                              const SizedBox(height: 20),
                                              _buildNextClassCard(userName),
                                              const SizedBox(height: 40),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (isDesktop) const SizedBox(width: 40),
                                      if (isDesktop)
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildSectionHeader("إحصائيات سريعة"),
                                              const SizedBox(height: 20),
                                              _buildQuickStatsCard(),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  
                                  if (_enrolledSessions.isNotEmpty) ...[
                                    _buildSectionHeader("جدول الحصص الأسبوعي"),
                                    const SizedBox(height: 20),
                                    _buildUpcomingGrid(),
                                  ],
                                  const SizedBox(height: 50),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          
          if (_isJoining)
            Container(
              color: Colors.black26,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30)],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF102A43)),
                      SizedBox(height: 20),
                      Text("جاري تحضير القاعة...", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(String name) {
    return SliverAppBar(
      expandedHeight: 80, pinned: true, elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.9),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: const Text("لوحة التحكم", 
          style: TextStyle(
            color: Color(0xFF102A43), 
            fontWeight: FontWeight.w800, 
            fontSize: 18,
            letterSpacing: -0.5,
          )
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
          child: IconButton(onPressed: () {}, icon: const Badge(child: Icon(Icons.notifications_outlined, color: Color(0xFF102A43)))),
        ),
        const SizedBox(width: 16),
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
        Row(
          children: [
            Text("$greeting، $name", 
              style: TextStyle(
                fontSize: Responsive.isMobile(context) ? 24 : 36, 
                fontWeight: FontWeight.w900, 
                color: const Color(0xFF102A43),
                letterSpacing: -1,
              )
            ),
            const SizedBox(width: 8),
            const Text("👋", style: TextStyle(fontSize: 28)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF102A43).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _enrolledSessions.isEmpty 
              ? "استمتع بيومك، لا توجد حصص مجدولة حالياً." 
              : "لديك ${_enrolledSessions.length} حصص متبقية اليوم. استعد جيداً!",
            style: const TextStyle(fontSize: 14, color: Color(0xFF486581), fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {bool isLive = false}) {
    return Row(
      children: [
        Container(
          width: 4, height: 24,
          decoration: BoxDecoration(
            color: isLive ? Colors.red : const Color(0xFF102A43),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF102A43))),
        if (isLive) ...[
          const SizedBox(width: 12),
          FadeTransition(
            opacity: _liveController,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
              child: const Text("مباشر", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildLiveSessionsCarousel() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _allActiveSessions.length,
        itemBuilder: (context, index) {
          final session = _allActiveSessions[index];
          return Container(
            width: 320,
            margin: const EdgeInsets.only(left: 20),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF102A43), Color(0xFF243B53)], 
                begin: Alignment.topLeft, 
                end: Alignment.bottomRight
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF102A43).withOpacity(0.2), 
                  blurRadius: 25, 
                  offset: const Offset(0, 12)
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.subjectName, 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20), 
                      overflow: TextOverflow.ellipsis
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_pin_rounded, color: Colors.white60, size: 16),
                        const SizedBox(width: 6),
                        Text("أ. ${session.teacherName}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _joinActiveSession(session),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF102A43),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text("انضمام للجلسة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF102A43),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          _buildStatRow(Icons.timer_outlined, "ساعات التعلم", _stats['learningHours'].toString()),
          const Divider(color: Colors.white12, height: 32),
          _buildStatRow(Icons.star_outline_rounded, "النقاط المكتسبة", _stats['points'].toString()),
          const Divider(color: Colors.white12, height: 32),
          _buildStatRow(Icons.history_rounded, "الحصص المكتملة", _stats['completedSessions'].toString()),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 22),
        const SizedBox(width: 16),
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  Widget _buildNextClassCard(String userName) {
    return NextClassCard(
      subject: _nextSession!.subjectName,
      teacher: _nextSession!.teacherName,
      startTime: intl.DateFormat('hh:mm a').format(_nextSession!.startTime),
      isLive: _nextSession!.isLive || _nextSession!.isActive,
      onJoin: () => _joinActiveSession(_nextSession!),
    );
  }

  void _showSessionOptions(SessionModel session) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: const BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 32),
              Text(session.subjectName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF102A43))),
              const SizedBox(height: 8),
              Text("المحاضر: أ. ${session.teacherName}", style: const TextStyle(color: Color(0xFF627D98), fontSize: 16)),
              const SizedBox(height: 40),
              _buildOptionTile(Icons.history_rounded, "تسجيلات الحصة", const Color(0xFF1565C0), () {
                Navigator.pop(context);
                // Future: Navigate to recordings
              }),
              const SizedBox(height: 16),
              _buildOptionTile(Icons.info_outline_rounded, "تفاصيل الحصة", const Color(0xFF2E7D32), () {
                Navigator.pop(context);
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05), 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12), 
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), 
              child: Icon(icon, color: color, size: 24)
            ),
            const SizedBox(width: 20),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF102A43))),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingGrid() {
    final upcoming = _enrolledSessions.where((s) => s.id != _nextSession?.id).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    int crossAxisCount = 1;
    if (Responsive.isDesktop(context)) {
      crossAxisCount = 3;
    } else if (Responsive.isTablet(context)) {
      crossAxisCount = 2;
    }

    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20, mainAxisSpacing: 20, mainAxisExtent: 110,
      ),
      itemCount: upcoming.length,
      itemBuilder: (context, index) {
        final session = upcoming[index];
        return InkWell(
          onTap: () => _showSessionOptions(session),
          borderRadius: BorderRadius.circular(20),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(height: 40, width: 300, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
            const SizedBox(height: 40),
            Container(height: 200, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32))),
            const SizedBox(height: 40),
            Container(height: 120, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32))),
            const SizedBox(height: 40),
            ...List.generate(3, (i) => Container(height: 100, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)))),
          ],
        ),
      ),
    );
  }
}
