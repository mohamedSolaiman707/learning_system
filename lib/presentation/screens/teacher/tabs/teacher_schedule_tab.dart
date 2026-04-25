import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/session_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final sessionsForSelectedDay = _getSessionsForDay(_selectedDay!);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("جدول حصصي", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCalendar(),
                const SizedBox(height: 16),
                _buildSessionsList(sessionsForSelectedDay),
              ],
            ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
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
          todayDecoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), shape: BoxShape.circle),
          selectedDecoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
          markerDecoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
        ),
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      ),
    );
  }

  Widget _buildSessionsList(List<SessionModel> sessions) {
    return Expanded(
      child: sessions.isEmpty
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text("لا توجد حصص في هذا اليوم", style: TextStyle(color: Colors.grey)),
              ],
            ))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.book, color: Colors.blue),
                    ),
                    title: Text(session.subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${DateFormat('hh:mm a').format(session.startTime)} - ${DateFormat('hh:mm a').format(session.endTime)}"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  ),
                );
              },
            ),
    );
  }
}
