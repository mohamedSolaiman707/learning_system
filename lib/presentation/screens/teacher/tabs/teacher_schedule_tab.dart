import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
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

  // دالة تحويل AM/PM إلى صباحاً ومساءً
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
        title: const Text("جدول حصصي", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: Responsive.isMobile(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: isDesktop
              ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCalendar(isDesktop),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                flex: 3,
                child: _buildSessionsList(sessionsForSelectedDay),
              ),
            ],
          )
              : Column(
            children: [
              _buildCalendar(isDesktop),
              const SizedBox(height: 16),
              _buildSessionsList(sessionsForSelectedDay),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(bool isDesktop) {
    return Container(
      margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isDesktop
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: isDesktop ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)] : null,
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
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
          todayTextStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          selectedDecoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
          markerDecoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
          markersMaxCount: 1,
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSessionsList(List<SessionModel> sessions) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "حصص يوم ${DateFormat('EEEE, d MMMM', 'ar_EG').format(_selectedDay!)}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text("${sessions.length} حصص", style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          Expanded(
            child: sessions.isEmpty
                ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available_outlined, size: 64, color: Colors.grey.shade200),
                const SizedBox(height: 16),
                const Text("يوم فارغ.. لا توجد حصص مجدولة", style: TextStyle(color: Colors.grey)),
              ],
            ))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade100),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
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
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.menu_book_rounded, color: Colors.blue),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(session.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${_formatTimeArabic(session.startTime)} - ${_formatTimeArabic(session.endTime)}",
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}