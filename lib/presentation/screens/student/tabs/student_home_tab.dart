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

  Future<void> _loadStudentDataWithCache() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _loadStudentData(initial: true);
  }

  void _updateNextSession() {
    final now = DateTime.now();
    try {
      _nextSession = _enrolledSessions.firstWhere(
        (s) => (s.isLive || s.isActive) && s.endTime.isAfter(now),
        orElse: () => _enrolledSessions.firstWhere((s) => s.endTime.isAfter(now)),
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
          // جلب آخر 5 تسجيلات للحصص اللي الطالب مسجل فيها
          db.getAllSessions(), // كحل مؤقت هنجيب كل الجلسات ونفلتر
        ]);

        final enrolledResponse = results[0] as List<Map<String, dynamic>>;
        final activeResponse = results[1] as List<Map<String, dynamic>>;
        final statsResponse = results[2] as Map<String, dynamic>;
        
        // جلب التسجيلات الحقيقية من الداتابيز
        final List<Map<String, dynamic>> recordings = [];
        for (var session in enrolledResponse) {
          final sId = session['session_id'];
          final sessionRecordings = await db.getSessionRecordings(sId);
          for (var rec in sessionRecordings) {
            rec['subject_name'] = session['sessions']['subject_name'];
            recordings.add(rec);
          }
        }

        if (mounted) {
          setState(() {
            _enrolledSessions = enrolledResponse
                .map((e) => SessionModel.fromMap(e['sessions']))
                .toList();
            
            _enrolledSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
            _allActiveSessions = activeResponse.map((e) => SessionModel.fromMap(e)).toList();
            _stats = statsResponse;
            _recentRecordings = recordings..sort((a, b) => b['created_at'].compareTo(a['created_at']));
            _updateNextSession();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Data loading error: $e");
      if (mounted && initial) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.profile?['full_name'] ?? "الطالب";
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadStudentData(initial: true),
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(userName),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildEnhancedWelcome(userName),
                              const SizedBox(height: 30),
                              _buildHorizontalStats(),
                              const SizedBox(height: 40),
                              
                              if (_recentRecordings.isNotEmpty) ...[
                                _buildSectionHeader("آخر المحاضرات المسجلة"),
                                const SizedBox(height: 16),
                                _buildRecentRecordingsList(),
                                const SizedBox(height: 40),
                              ],

                              if (_nextSession != null) ...[
                                _buildSectionHeader("الحصة القادمة"),
                                const SizedBox(height: 16),
                                NextClassCard(
                                  subject: _nextSession!.subjectName,
                                  teacher: _nextSession!.teacherName,
                                  startTime: intl.DateFormat('hh:mm a').format(_nextSession!.startTime),
                                  isLive: _nextSession!.isActive,
                                  onJoin: () {}, // سيتم ربطها لاحقاً
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRecentRecordingsList() {
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
              if (await canLaunchUrl(url)) await launchUrl(url);
            },
            child: Container(
              width: 240,
              margin: const EdgeInsets.only(left: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.play_circle_fill, color: Colors.red, size: 30),
                      const Spacer(),
                      Text(
                        intl.DateFormat('MMM dd').format(DateTime.parse(rec['created_at'])),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    rec['subject_name'] ?? 'محاضرة مسجلة',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text("اضغط للمشاهدة", style: TextStyle(fontSize: 12, color: Colors.blue)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // الـ Widgets التانية (SliverAppBar, Stats, etc.) تبقى كما هي مع التأكد من توافقها
  Widget _buildSliverAppBar(String name) => SliverAppBar(title: const Text("لوحة التحكم"), pinned: true);
  Widget _buildEnhancedWelcome(String name) => Text("مرحباً، $name", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
  Widget _buildSectionHeader(String title) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  
  Widget _buildHorizontalStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatCard("ساعات التعلم", _stats['learningHours'].toString(), Icons.timer, Colors.blue),
        _buildStatCard("النقاط", _stats['points'].toString(), Icons.star, Colors.orange),
        _buildStatCard("الحصص", _stats['completedSessions'].toString(), Icons.check_circle, Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            Icon(icon, color: color),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
