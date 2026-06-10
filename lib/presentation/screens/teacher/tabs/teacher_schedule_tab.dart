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
      debugPrint("Error fetching teacher schedule: $e");
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
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("الجدول الدراسي", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18, color: Color(0xFF102A43))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: Responsive.isMobile(context),
        iconTheme: const IconThemeData(color: Color(0xFF102A43)),
        actions: [
          IconButton(onPressed: _fetchTeacherSchedule, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: _isLoading
              ? _buildLoadingSkeleton()
              : RefreshIndicator(
                  onRefresh: _fetchTeacherSchedule,
                  child: Responsive(
                    mobile: _buildMobileLayout(sessionsForSelectedDay),
                    desktop: _buildDesktopLayout(sessionsForSelectedDay),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(List<SessionModel> sessions) {
    return Column(
      children: [
        _buildCalendar(false),
        const SizedBox(height: 8),
        Expanded(child: _buildSessionsList(sessions)),
      ],
    );
  }

  Widget _buildDesktopLayout(List<SessionModel> sessions) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildCalendar(true),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: Colors.black12),
        Expanded(
          flex: 3,
          child: _buildSessionsList(sessions),
        ),
      ],
    );
  }

  Widget _buildCalendar(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
          todayTextStyle: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          selectedDecoration: BoxDecoration(color: Color(0xFF102A43), shape: BoxShape.circle),
          markerDecoration: BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
          markerMargin: EdgeInsets.only(top: 8),
          defaultTextStyle: TextStyle(fontFamily: 'Cairo'),
          weekendTextStyle: TextStyle(fontFamily: 'Cairo', color: Colors.redAccent),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Color(0xFF102A43)),
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "حصص ${DateFormat('EEEE, d MMMM', 'ar_EG').format(_selectedDay!)}",
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Color(0xFF102A43)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF102A43).withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                child: Text("${sessions.length} حصص", style: const TextStyle(color: Color(0xFF102A43), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              )
            ],
          ),
        ),
        Expanded(
          child: sessions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.menu_book_rounded, color: Colors.blue, size: 28),
        ),
        title: Text(session.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Cairo', color: Color(0xFF102A43))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                "${_formatTimeArabic(session.startTime)} - ${_formatTimeArabic(session.endTime)}",
                style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.blueGrey),
        ),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.event_available_outlined, size: 80, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          const Text("لا توجد حصص مجدولة لهذا اليوم", style: TextStyle(color: Colors.grey, fontSize: 16, fontFamily: 'Cairo')),
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
