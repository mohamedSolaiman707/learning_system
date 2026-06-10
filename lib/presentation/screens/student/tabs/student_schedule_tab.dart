import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/models/session_model.dart';
import '../../video_room/video_room_screen.dart';
import '../../video_room/video_room_controller.dart';

class StudentScheduleTab extends StatefulWidget {
  const StudentScheduleTab({super.key});

  @override
  State<StudentScheduleTab> createState() => _StudentScheduleTabState();
}

class _StudentScheduleTabState extends State<StudentScheduleTab> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<SessionModel> _allSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadScheduleWithCache();
  }

  String _formatTimeArabic(DateTime time) {
    String formatted = DateFormat('hh:mm').format(time.toLocal());
    return "$formatted ${time.toLocal().hour < 12 ? "صباحاً" : "مساءً"}";
  }

  Future<void> _loadScheduleWithCache() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final cache = Provider.of<CacheService>(context, listen: false);
    try {
      final cachedSessions = await cache.getEnrolledSessions();
      if (mounted && cachedSessions != null) {
        setState(() {
          _allSessions = cachedSessions
              .map((e) => SessionModel.fromMap(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Schedule cache error: $e");
    }
    await _loadSchedule(initial: _isLoading);
  }

  Future<void> _loadSchedule({bool initial = true}) async {
    if (!mounted) return;
    if (initial) setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      final cache = Provider.of<CacheService>(context, listen: false);
      final data = await db.getStudentSchedule(auth.user!.id);
      final sessionMaps = data
          .map((e) => e['sessions'] as Map<String, dynamic>)
          .toList();
      await cache.saveEnrolledSessions(sessionMaps);
      if (mounted) {
        setState(() {
          _allSessions = data
              .map((e) => SessionModel.fromMap(e['sessions']))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && initial) setState(() => _isLoading = false);
    }
  }

  void _showJoinCodeDialog() {
    final codeController = TextEditingController();
    bool isSubmitting = false;
    final bool isDesktop = Responsive.isDesktop(context);

    showDialog(
      context: context,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 500 : double.infinity),
          child: StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text("انضمام لحصة جديدة", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "أدخل كود الحصة المكون من 6 أرقام أو حروف",
                    style: TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Cairo'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: codeController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 6, color: Color(0xFF102A43)),
                    decoration: InputDecoration(
                      hintText: "ABC123",
                      hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 6),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF102A43), width: 1.5)),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (codeController.text.isEmpty) return;
                          setDialogState(() => isSubmitting = true);
                          try {
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            final db = Provider.of<DatabaseService>(context, listen: false);
                            await db.enrollStudentByCode(auth.user!.id, codeController.text.trim().toUpperCase());
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("تمت الإضافة لجدولك بنجاح ✅", style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
                              );
                              _loadSchedule(initial: true);
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""), style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF102A43),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("انضمام الآن", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<SessionModel> _getSessionsForDay(DateTime day) {
    return _allSessions.where((s) => isSameDay(s.startTime, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("الجدول الدراسي", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18, color: Color(0xFF102A43))),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _showJoinCodeDialog, icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF102A43), size: 28)),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: _isLoading
              ? _buildLoadingSkeleton()
              : RefreshIndicator(
                  onRefresh: () => _loadSchedule(initial: true),
                  child: Responsive(
                    mobile: _buildMobileLayout(),
                    desktop: _buildDesktopLayout(),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildCalendarCard(),
        Expanded(child: _buildSessionsList(_getSessionsForDay(_selectedDay!))),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: _buildCalendarCard(),
          ),
        ),
        const VerticalDivider(width: 1, color: Colors.black12),
        Expanded(
          flex: 3,
          child: _buildSessionsList(_getSessionsForDay(_selectedDay!)),
        ),
      ],
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 5)),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        locale: 'ar_EG',
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() => _calendarFormat = format);
        },
        eventLoader: (day) => _getSessionsForDay(day),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo', color: Color(0xFF102A43)),
          leftChevronIcon: Icon(Icons.chevron_left_rounded, color: Color(0xFF102A43)),
          rightChevronIcon: Icon(Icons.chevron_right_rounded, color: Color(0xFF102A43)),
        ),
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
          todayTextStyle: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          selectedDecoration: BoxDecoration(color: Color(0xFF102A43), shape: BoxShape.circle),
          markerDecoration: BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
          markerMargin: EdgeInsets.only(top: 8),
          defaultTextStyle: TextStyle(fontFamily: 'Cairo'),
          weekendTextStyle: TextStyle(fontFamily: 'Cairo', color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildSessionsList(List<SessionModel> sessions) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(Icons.event_busy_rounded, size: 80, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 24),
            const Text("لا توجد حصص مجدولة لهذا اليوم", style: TextStyle(color: Colors.grey, fontSize: 16, fontFamily: 'Cairo')),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showJoinCodeDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text("انضم لحصة جديدة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF102A43).withOpacity(0.05),
                foregroundColor: const Color(0xFF102A43),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userName = authProvider.profile?['full_name'] ?? "Student";
    final userId = authProvider.user?.id ?? "";

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isLive = session.isLive;
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isLive ? Colors.red : Colors.blue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(isLive ? Icons.sensors_rounded : Icons.menu_book_rounded, color: isLive ? Colors.red : Colors.blue, size: 28),
            ),
            title: Text(session.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Cairo', color: Color(0xFF102A43))),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text("أ. ${session.teacherName}", style: const TextStyle(fontSize: 13, fontFamily: 'Cairo', color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(_formatTimeArabic(session.startTime), style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
                  ],
                ),
              ],
            ),
            trailing: isLive
                ? ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
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
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("دخول الآن", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  )
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Column(
        children: [
          Container(
            height: 380,
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: 3,
              itemBuilder: (_, __) => Container(
                height: 110,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
