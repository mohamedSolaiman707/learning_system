import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/utils/responsive.dart';
import '../attendance/attendance_screen.dart';

class TeacherScheduleTab extends StatefulWidget {
  const TeacherScheduleTab({super.key});

  @override
  State<TeacherScheduleTab> createState() => _TeacherScheduleTabState();
}

class _TeacherScheduleTabState extends State<TeacherScheduleTab> {
  final supabase = Supabase.instance.client;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<SessionModel> _allSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchTeacherSchedule();
  }

  Future<void> _fetchTeacherSchedule() async {
    try {
      final teacherId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('sessions')
          .select('*, profiles:teacher_id(full_name)')
          .eq('teacher_id', teacherId);

      if (mounted) {
        setState(() {
          _allSessions = (response as List).map((s) => SessionModel.fromMap(s)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<SessionModel> _getSessionsForDay(DateTime day) {
    return _allSessions.where((session) => isSameDay(session.startTime, day)).toList();
  }

  String _formatTimeArabic(DateTime time) {
    String formatted = DateFormat('hh:mm').format(time.toLocal());
    return "$formatted ${time.toLocal().hour < 12 ? "صباحاً" : "مساءً"}";
  }

  @override
  Widget build(BuildContext context) {
    final sessionsForSelectedDay = _getSessionsForDay(_selectedDay!);
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.transparent, // Consistent with Main Layout
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("الجدول الدراسي", 
          style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 22, color: Color(0xFF102A43))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _fetchTeacherSchedule, 
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF102A43).withOpacity(0.05), shape: BoxShape.circle),
              child: const Icon(Icons.refresh_rounded, color: Color(0xFF102A43), size: 20)
            )
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _fetchTeacherSchedule,
              child: Responsive(
                mobile: _buildMobileLayout(sessionsForSelectedDay),
                desktop: _buildDesktopLayout(sessionsForSelectedDay),
              ),
            ),
    );
  }

  Widget _buildMobileLayout(List<SessionModel> sessions) {
    return Column(
      children: [
        _buildCalendar(false),
        const SizedBox(height: 20),
        Expanded(child: _buildSessionsList(sessions)),
      ],
    );
  }

  Widget _buildDesktopLayout(List<SessionModel> sessions) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _buildCalendar(true),
          ),
          const SizedBox(width: 40),
          Expanded(
            flex: 3,
            child: _buildSessionsList(sessions),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 5)),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
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
        onFormatChanged: (format) => setState(() => _calendarFormat = format),
        eventLoader: _getSessionsForDay,
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
          todayTextStyle: TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.bold),
          selectedDecoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF102A43), Color(0xFF243B53)]),
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
          markerMargin: EdgeInsets.only(top: 8),
          defaultTextStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
          weekendTextStyle: TextStyle(fontFamily: 'Cairo', color: Colors.redAccent),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Cairo', color: Color(0xFF102A43)),
          leftChevronIcon: Icon(Icons.chevron_left_rounded, color: Color(0xFF102A43)),
          rightChevronIcon: Icon(Icons.chevron_right_rounded, color: Color(0xFF102A43)),
        ),
      ),
    );
  }

  Widget _buildSessionsList(List<SessionModel> sessions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, d MMMM', 'ar_EG').format(_selectedDay!),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Cairo', color: Color(0xFF102A43)),
                  ),
                  Text(
                    "إجمالي الحصص اليوم: ${sessions.length}",
                    style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade400, fontFamily: 'Cairo'),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF102A43).withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.calendar_view_day_rounded, color: Color(0xFF102A43)),
              )
            ],
          ),
        ),
        Expanded(
          child: sessions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) => _buildSessionCard(sessions[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(SessionModel session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceScreen(
                  sessionId: session.id,
                  subjectName: session.subjectName,
                  teacherName: supabase.auth.currentUser!.userMetadata?['full_name'],
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF2196F3), size: 26),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.subjectName, 
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Cairo', color: Color(0xFF102A43))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: Colors.blueGrey.shade300),
                          const SizedBox(width: 6),
                          Text(
                            "${_formatTimeArabic(session.startTime)} - ${_formatTimeArabic(session.endTime)}",
                            style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12, fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.blueGrey.shade200),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(Icons.event_available_outlined, size: 60, color: Colors.blueGrey.shade200),
          ),
          const SizedBox(height: 20),
          const Text("اليوم خالٍ من الحصص، استمتع بوقتك!", 
            style: TextStyle(color: Colors.blueGrey, fontSize: 15, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
        ],
      ),
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
            margin: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              itemCount: 3,
              itemBuilder: (_, __) => Container(
                height: 100,
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
