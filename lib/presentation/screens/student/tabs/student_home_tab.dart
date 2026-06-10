import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/models/session_model.dart';
import '../widgets/next_class_card.dart';
import '../../video_room/video_room_screen.dart';
import '../../video_room/video_room_controller.dart';
import '../../video_room/waiting_room_screen.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isJoining = false;
  List<SessionModel> _enrolledSessions = [];
  List<SessionModel> _allActiveSessions = [];
  List<SessionModel> _allUpcomingSessions =
      []; // القائمة الجديدة لكل الحصص المجدولة
  List<Map<String, dynamic>> _recentRecordings = [];
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

    _loadStudentDataWithCache();

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

  String _clean(String? text) {
    if (text == null) return "";
    return text.replaceAll("AM", "صباحاً").replaceAll("PM", "مساءً");
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    String timeStr =
        intl.DateFormat('hh:mm').format(local) +
        (local.hour < 12 ? " صباحاً" : " مساءً");

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return "اليوم - $timeStr";
    } else {
      return "${intl.DateFormat('dd/MM').format(local)} - $timeStr";
    }
  }

  Future<void> _loadStudentDataWithCache() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final cache = Provider.of<CacheService>(context, listen: false);
    try {
      final cachedStats = await cache.getStudentStats();
      final cachedEnrolled = await cache.getEnrolledSessions();
      if (mounted && (cachedStats != null || cachedEnrolled != null)) {
        setState(() {
          if (cachedStats != null) _stats = cachedStats;
          if (cachedEnrolled != null) {
            _enrolledSessions = cachedEnrolled
                .map((e) => SessionModel.fromMap(e))
                .toList();
            _updateNextSession();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Cache loading error: $e");
    }
    await _loadStudentData(initial: _isLoading);
  }

  void _updateNextSession() {
    final now = DateTime.now();
    try {
      _nextSession = _enrolledSessions.firstWhere(
        (s) => (s.isLive || s.isActive) && s.endTime.isAfter(now),
        orElse: () =>
            _enrolledSessions.firstWhere((s) => s.endTime.isAfter(now)),
      );
    } catch (_) {
      _nextSession = null;
    }
  }

  Future<void> _loadStudentData({bool initial = true}) async {
    if (!mounted) return;
    if (initial) setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      if (auth.user != null) {
        final results = await Future.wait([
          db.getStudentSchedule(auth.user!.id),
          db.getActiveSessions(),
          db.getStudentStats(auth.user!.id),
          db.getAllSessions(), // جلب كل الحصص المجدولة في الأكاديمية
        ]);

        final enrolledResponse = results[0] as List<Map<String, dynamic>>;
        final activeResponse = results[1] as List<Map<String, dynamic>>;
        final statsResponse = results[2] as Map<String, dynamic>;
        final allSessionsResponse = results[3] as List<Map<String, dynamic>>;

        final List<Map<String, dynamic>> allRecs = [];
        for (var enrollment in enrolledResponse) {
          final sId = enrollment['session_id'];
          final recs = await db.getSessionRecordings(sId);
          for (var r in recs) {
            r['subject_name'] = enrollment['sessions']['subject_name'];
            allRecs.add(r);
          }
        }

        final now = DateTime.now();

        if (mounted) {
          setState(() {
            _enrolledSessions = enrolledResponse
                .map((e) => SessionModel.fromMap(e['sessions']))
                .toList();
            _enrolledSessions.sort(
              (a, b) => a.startTime.compareTo(b.startTime),
            );

            _allActiveSessions = activeResponse
                .map((e) => SessionModel.fromMap(e))
                .toList();

            // فلترة كل الحصص القادمة التي لم تنتهِ بعد
            _allUpcomingSessions =
                allSessionsResponse
                    .map((e) => SessionModel.fromMap(e))
                    .where((s) => s.endTime.isAfter(now))
                    .toList()
                  ..sort((a, b) => a.startTime.compareTo(b.startTime));

            _stats = statsResponse;
            _recentRecordings = allRecs
              ..sort((a, b) => b['created_at'].compareTo(a['created_at']));
            _updateNextSession();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && initial) setState(() => _isLoading = false);
    }
  }

  void _showUpcomingClasses() {
    final now = DateTime.now();
    final upcoming = _allUpcomingSessions;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 12),
                const Text(
                  "جدول الحصص القادمة",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${upcoming.length} حصة مجدولة",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (upcoming.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    "لا توجد حصص مجدولة حالياً 🎉",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: upcoming.length,
                  itemBuilder: (context, index) {
                    final session = upcoming[index];
                    final bool isNow =
                        session.startTime.isBefore(now) &&
                        session.endTime.isAfter(now);
                    final bool isToday =
                        session.startTime.year == now.year &&
                        session.startTime.month == now.month &&
                        session.startTime.day == now.day;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isNow
                            ? Colors.red.withOpacity(0.05)
                            : (isToday
                                  ? Colors.blue.withOpacity(0.02)
                                  : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isNow
                              ? Colors.red.withOpacity(0.2)
                              : Colors.transparent,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isNow
                              ? Colors.red
                              : (isToday
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.grey.shade200),
                          child: Icon(
                            isNow
                                ? Icons.sensors
                                : (isToday
                                      ? Icons.access_time
                                      : Icons.calendar_today),
                            color: isNow
                                ? Colors.white
                                : (isToday ? Colors.blue : Colors.grey),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          _clean(session.subjectName),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isNow
                              ? "جارية الآن (اضغط للانضمام)"
                              : "موعدها: ${_formatDateTime(session.startTime)}",
                          style: TextStyle(
                            color: isNow ? Colors.red : Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        trailing: !isNow && !isToday
                            ? Text(
                                "بعد ${session.startTime.difference(DateTime(now.year, now.month, now.day)).inDays} يوم",
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.blueGrey,
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _joinActiveSession(session);
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
          const SnackBar(
            content: Text("عذراً، تم استبعادك من هذه الحصة 🚫"),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isJoining = false);
        return;
      }
      await db.enrollStudentBySessionId(auth.user!.id, session.id);
      if (!mounted) return;
      final String userName = auth.profile?['full_name'] ?? "الطالب";
      final String userId = auth.user!.id;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => session.status == 'waiting'
              ? WaitingRoomScreen(
                  session: session,
                  userName: userName,
                  userId: userId,
                )
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
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("يرجى المحاولة مرة أخرى")));
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.profile?['full_name'] ?? "الطالب";
    final isDesktop = Responsive.isDesktop(context);
    final upcomingCount = _allUpcomingSessions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF102A43)),
                )
              : RefreshIndicator(
                  color: const Color(0xFF102A43),
                  onRefresh: () => _loadStudentData(initial: true),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      _buildSliverAppBar(userName, upcomingCount),
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 40 : 20,
                                vertical: 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildEnhancedWelcome(userName),
                                  const SizedBox(height: 30),
                                  _buildHorizontalStats(),
                                  const SizedBox(height: 40),
                                  if (_allActiveSessions.isNotEmpty) ...[
                                    _buildSectionHeader(
                                      "البث المباشر المتاح",
                                      isLive: true,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildLiveSessionsCarousel(),
                                    const SizedBox(height: 40),
                                  ],
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (_nextSession != null) ...[
                                              _buildSectionHeader(
                                                "الحصة القادمة",
                                              ),
                                              const SizedBox(height: 16),
                                              _buildNextClassCard(userName),
                                              const SizedBox(height: 40),
                                            ],
                                            _buildSectionHeader(
                                              "آخر المحاضرات المسجلة",
                                            ),
                                            const SizedBox(height: 16),
                                            _buildRecentRecordingsList(),
                                            const SizedBox(height: 40),
                                            _buildSectionHeader(
                                              "الجدول الزمني لليوم",
                                            ),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildSectionHeader("التنبيهات"),
                                              const SizedBox(height: 16),
                                              _buildAnnouncementsCard(),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          if (_isJoining) _buildJoiningOverlay(),
        ],
      ),
    );
  }

  Widget _buildRecentRecordingsList() {
    if (_recentRecordings.isEmpty) {
      return Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            "لا توجد تسجيلات متاحة حالياً",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recentRecordings.length,
        itemBuilder: (context, index) {
          final rec = _recentRecordings[index];
          return GestureDetector(
            onTap: () async {
              final url = Uri.parse(rec['video_url'] ?? '');
              if (await canLaunchUrl(url))
                await launchUrl(url, mode: LaunchMode.externalApplication);
            },
            child: Container(
              width: 280,
              margin: const EdgeInsets.only(left: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        intl.DateFormat(
                          'dd MMM',
                        ).format(DateTime.parse(rec['created_at'])),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _clean(rec['subject_name'] ?? 'محاضرة مسجلة'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF102A43),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    "اضغط للمشاهدة الآن",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(String name, int upcomingCount) {
    return SliverAppBar(
      expandedHeight: 70,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.9),
      title: const Text(
        "لوحة التحكم",
        style: TextStyle(
          color: Color(0xFF102A43),
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          onPressed: _showUpcomingClasses,
          icon: Badge(
            isLabelVisible: upcomingCount > 0,
            label: Text(upcomingCount.toString()),
            child: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF102A43),
            ),
          ),
        ),
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
            Text(
              "مرحباً بك، $name",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF102A43),
              ),
            ),
            const SizedBox(width: 8),
            const Text("✨", style: TextStyle(fontSize: 24)),
          ],
        ),
        const Text(
          "استمتع بيومك الدراسي وواصل التقدم في مهاراتك.",
          style: TextStyle(fontSize: 14, color: Color(0xFF627D98)),
        ),
      ],
    );
  }

  Widget _buildHorizontalStats() {
    final bool isDesktop = Responsive.isDesktop(context);
    final bool isTablet = Responsive.isTablet(context);

    if (isDesktop || isTablet) {
      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              "ساعات التعلم",
              _stats['learningHours'].toString(),
              Icons.timer_outlined,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _buildStatCard(
              "النقاط المكتسبة",
              _stats['points'].toString(),
              Icons.stars_rounded,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _buildStatCard(
              "الحصص المكتملة",
              _stats['completedSessions'].toString(),
              Icons.check_circle_outline,
              Colors.green,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _buildStatCard(
          "ساعات التعلم",
          _stats['learningHours'].toString(),
          Icons.timer_outlined,
          Colors.blue,
        ),
        _buildStatCard(
          "النقاط المكتسبة",
          _stats['points'].toString(),
          Icons.stars_rounded,
          Colors.orange,
        ),
        _buildStatCard(
          "الحصص المكتملة",
          _stats['completedSessions'].toString(),
          Icons.check_circle_outline,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isMobile = Responsive.isMobile(context);
    return Container(
      width: isMobile ? double.infinity : null,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF102A43),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF627D98),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTimeline() {
    final now = DateTime.now();
    final todaySessions = _enrolledSessions
        .where(
          (s) =>
              s.startTime.year == now.year &&
              s.startTime.month == now.month &&
              s.startTime.day == now.day,
        )
        .toList();

    if (todaySessions.isEmpty)
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: Text("لا توجد حصص في جدولك اليوم")),
      );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: todaySessions.length,
        itemBuilder: (context, index) {
          final session = todaySessions[index];
          final bool isNow =
              session.startTime.isBefore(now) && session.endTime.isAfter(now);
          final bool isPast = session.endTime.isBefore(now);

          return Opacity(
            opacity: isPast ? 0.5 : 1.0,
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isNow
                            ? Colors.blue
                            : (isPast ? Colors.grey : Colors.grey.shade300),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (index != todaySessions.length - 1)
                      Container(
                        width: 2,
                        height: 40,
                        color: Colors.grey.shade100,
                      ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDateTime(session.startTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: isNow ? Colors.blue : Colors.grey,
                        ),
                      ),
                      Text(
                        _clean(session.subjectName),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: isPast
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveSessionsCarousel() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _allActiveSessions.length,
        itemBuilder: (context, index) {
          final session = _allActiveSessions[index];
          return Container(
            width: 320,
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF102A43), Color(0xFF243B53)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _clean(session.subjectName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (session.isRecording) const _RecIndicator(),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _joinActiveSession(session),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF102A43),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("انضمام الآن"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isLive = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF102A43),
          ),
        ),
        if (isLive) ...[
          const SizedBox(width: 12),
          FadeTransition(
            opacity: _liveController,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "مباشر",
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNextClassCard(String userName) {
    return Stack(
      children: [
        NextClassCard(
          subject: _clean(_nextSession!.subjectName),
          teacher: _nextSession!.teacherName,
          startTime: _formatDateTime(_nextSession!.startTime),
          isLive: _nextSession!.isActive,
          onJoin: () => _joinActiveSession(_nextSession!),
        ),
        if (_nextSession!.isRecording)
          Positioned(top: 15, left: 15, child: const _RecIndicator()),
      ],
    );
  }

  Widget _buildAnnouncementsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A43), Color(0xFF243B53)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, color: Colors.orangeAccent),
              SizedBox(width: 10),
              Text(
                "تنبيهات هامة",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            "تأكد من مراجعة تسجيلات المحاضرات السابقة في قسم التسجيلات.",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildJoiningOverlay() {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF102A43)),
              SizedBox(height: 20),
              Text(
                "جاري تحضير القاعة...",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecIndicator extends StatefulWidget {
  const _RecIndicator();
  @override
  State<_RecIndicator> createState() => _RecIndicatorState();
}

class _RecIndicatorState extends State<_RecIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
            SizedBox(width: 4),
            Text(
              "REC",
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
