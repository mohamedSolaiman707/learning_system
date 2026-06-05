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
        final enrolledResponse = await db.getStudentSchedule(auth.user!.id);
        final activeResponse = await db.getActiveSessions();
        final statsResponse = await db.getStudentStats(auth.user!.id);

        if (mounted) {
          final now = DateTime.now();
          final List<SessionModel> tempEnrolled = enrolledResponse
                .map((e) => SessionModel.fromMap(e['sessions']))
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
            _stats = statsResponse;
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
      
      bool isKicked = await db.isStudentKicked(session.id, auth.user!.id);

      if (isKicked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("عذراً، تم استبعادك من هذه الحصة 🚫"), backgroundColor: Colors.redAccent),
        );
        setState(() => _isJoining = false);
        return;
      }

      await db.enrollStudentBySessionId(auth.user!.id, session.id);

      if (!mounted) return;
      final String userName = auth.profile?['full_name'] ?? "الطالب";
      final String userId = auth.user!.id;

      Navigator.push(context, MaterialPageRoute(
        builder: (context) => session.status == 'waiting' 
          ? WaitingRoomScreen(session: session, userName: userName, userId: userId)
          : ChangeNotifierProvider(
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
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى المحاولة مرة أخرى")));
    } finally {
      if (mounted) setState(() => _isJoining = false);
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
                                  const SizedBox(height: 30),
                                  
                                  // Stats Row
                                  _buildHorizontalStats(),
                                  const SizedBox(height: 40),

                                  if (_allActiveSessions.isNotEmpty) ...[
                                    _buildSectionHeader("البث المباشر المتاح", isLive: true),
                                    const SizedBox(height: 16),
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
                                              const SizedBox(height: 16),
                                              _buildNextClassCard(userName),
                                              const SizedBox(height: 40),
                                            ],
                                            _buildSectionHeader("آخر المحاضرات المسجلة"),
                                            const SizedBox(height: 16),
                                            _buildRecentRecordings(),
                                            const SizedBox(height: 40),
                                            _buildSectionHeader("الجدول الزمني لليوم"),
                                            const SizedBox(height: 16),
                                            _buildTodayTimeline(),
                                          ],
                                        ),
                                      ),
                                      if (isDesktop) const SizedBox(width: 30),
                                      if (isDesktop)
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildSectionHeader("نشاطك الأسبوعي"),
                                              const SizedBox(height: 16),
                                              _buildActivityChart(),
                                              const SizedBox(height: 30),
                                              _buildSectionHeader("التنبيهات"),
                                              const SizedBox(height: 16),
                                              _buildAnnouncementsCard(),
                                              const SizedBox(height: 30),
                                              _buildSectionHeader("روابط سريعة"),
                                              const SizedBox(height: 16),
                                              _buildQuickLinks(),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
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
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
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
      expandedHeight: 70, pinned: true, elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.9),
      surfaceTintColor: Colors.transparent,
      title: const Text("لوحة التحكم", style: TextStyle(color: Color(0xFF102A43), fontWeight: FontWeight.w800, fontSize: 18)),
      actions: [
        IconButton(onPressed: () {}, icon: const Badge(child: Icon(Icons.notifications_outlined, color: Color(0xFF102A43)))),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildEnhancedWelcome(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("مرحباً بك، $name", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF102A43))),
            const SizedBox(width: 8),
            const Text("✨", style: TextStyle(fontSize: 24)),
          ],
        ),
        const Text("استمتع بيومك الدراسي وواصل التقدم في مهاراتك.", style: TextStyle(fontSize: 14, color: Color(0xFF627D98))),
      ],
    );
  }

  Widget _buildHorizontalStats() {
    return LayoutBuilder(builder: (context, constraints) {
      return Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          _buildStatCard("ساعات التعلم", _stats['learningHours'].toString(), Icons.timer_outlined, Colors.blue),
          _buildStatCard("النقاط المكتسبة", _stats['points'].toString(), Icons.stars_rounded, Colors.orange),
          _buildStatCard("الحصص المكتملة", _stats['completedSessions'].toString(), Icons.check_circle_outline, Colors.green),
        ],
      );
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final isMobile = Responsive.isMobile(context);
    return Container(
      width: isMobile ? double.infinity : (MediaQuery.of(context).size.width > 1200 ? 250 : 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF102A43))),
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF627D98), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRecordings() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 3, // Placeholder for real recording data
        itemBuilder: (context, index) {
          final titles = ["محاضرة الرياضيات 1", "أساسيات البرمجة", "اللغة العربية - البلاغة"];
          return Container(
            width: 220,
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.play_circle_fill, color: Colors.red, size: 20),
                    ),
                    const Spacer(),
                    const Text("45 دقيقة", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                Text(titles[index], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, overflow: TextOverflow.ellipsis)),
                const Text("تم التسجيل أمس", style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final heights = [40.0, 70.0, 50.0, 90.0, 30.0, 80.0, 60.0];
              final days = ["S", "M", "T", "W", "T", "F", "S"];
              return Column(
                children: [
                  Container(
                    width: 12,
                    height: 100,
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          width: 12,
                          height: heights[index],
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.blue.shade300, Colors.blue.shade600], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(days[index], style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          const Text("ساعات التعلم هذا الأسبوع", style: TextStyle(fontSize: 12, color: Color(0xFF627D98))),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isLive = false}) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF102A43))),
        const Spacer(),
        if (isLive) 
          FadeTransition(
            opacity: _liveController,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
              child: const Text("مباشر", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildTodayTimeline() {
    if (_enrolledSessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: Text("لا توجد حصص مسجلة في جدولك اليوم")),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _enrolledSessions.length,
        itemBuilder: (context, index) {
          final session = _enrolledSessions[index];
          final bool isPast = session.endTime.isBefore(DateTime.now());
          final bool isNow = session.startTime.isBefore(DateTime.now()) && session.endTime.isAfter(DateTime.now());

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: isNow ? Colors.blue : (isPast ? Colors.grey.shade300 : Colors.blue.shade100),
                      shape: BoxShape.circle,
                      border: isNow ? Border.all(color: Colors.blue.withOpacity(0.2), width: 4) : null,
                    ),
                  ),
                  if (index != _enrolledSessions.length - 1)
                    Container(width: 2, height: 40, color: Colors.grey.shade100),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(intl.DateFormat('hh:mm a').format(session.startTime), 
                        style: TextStyle(fontSize: 12, color: isNow ? Colors.blue : Colors.grey, fontWeight: isNow ? FontWeight.bold : FontWeight.normal)),
                    Text(session.subjectName, 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isPast ? Colors.grey : const Color(0xFF102A43))),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF102A43), Color(0xFF243B53)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF102A43).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, color: Colors.orangeAccent, size: 24),
              SizedBox(width: 10),
              Text("تنبيهات هامة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          SizedBox(height: 12),
          Text("تم رفع تسجيلات محاضرة الرياضيات الأخيرة، يمكنك مراجعتها الآن.", 
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildQuickLinks() {
    return Column(
      children: [
        _buildLinkTile("المكتبة الرقمية", Icons.menu_book_rounded, Colors.purple),
        const SizedBox(height: 12),
        _buildLinkTile("الدعم الفني", Icons.support_agent_rounded, Colors.blue),
      ],
    );
  }

  Widget _buildLinkTile(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF102A43))),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        ],
      ),
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
              gradient: const LinearGradient(colors: [Color(0xFF102A43), Color(0xFF243B53)]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.subjectName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text("أ. ${session.teacherName}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _joinActiveSession(session),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, 
                    foregroundColor: const Color(0xFF102A43), 
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildNextClassCard(String userName) {
    return NextClassCard(
      subject: _nextSession!.subjectName,
      teacher: _nextSession!.teacherName,
      startTime: intl.DateFormat('hh:mm a').format(_nextSession!.startTime),
      isLive: _nextSession!.isLive || _nextSession!.isActive,
      onJoin: () => _joinActiveSession(_nextSession!),
    );
  }

  Widget _buildLoadingSkeleton() {
    return const Center(child: CircularProgressIndicator(color: Color(0xFF102A43)));
  }
}
