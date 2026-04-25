import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/session_model.dart';
import '../../video_room/video_room_screen.dart';

class StudentScheduleTab extends StatefulWidget {
  const StudentScheduleTab({super.key});

  @override
  State<StudentScheduleTab> createState() => _StudentScheduleTabState();
}

class _StudentScheduleTabState extends State<StudentScheduleTab> {
  final supabase = Supabase.instance.client;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<SessionModel> _allSessions = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchSchedule();
    // تحديث الجدول كل 30 ثانية لضمان دقة مواعيد انتهاء الحصص
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _filterSessionsLocally();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSchedule() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('enrollments')
          .select('sessions(*, profiles:teacher_id(full_name), rooms(is_active))')
          .eq('student_id', userId);

      final List<dynamic> data = response as List;

      if (mounted) {
        setState(() {
          _allSessions = data.map((item) {
            final sessionData = item['sessions'];
            final rooms = sessionData['rooms'] as List?;
            final bool isLiveNow = rooms != null && rooms.any((r) => r['is_active'] == true);

            final session = SessionModel.fromMap(sessionData);
            return SessionModel(
              id: session.id,
              subjectName: session.subjectName,
              teacherName: session.teacherName,
              startTime: session.startTime,
              endTime: session.endTime,
              isLive: isLiveNow,
            );
          }).toList();
          _isLoading = false;
          _filterSessionsLocally();
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterSessionsLocally() {
    final now = DateTime.now();
    setState(() {
      // لا نحذف الحصص من الجدول بالكامل لكي يراها الطالب كسجل، 
      // ولكننا فقط سنقوم بتمييز الحصص المنتهية أو القادمة
      _allSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
    });
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
          Expanded(child: _buildSessionsList(sessionsForSelectedDay)),
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
    final now = DateTime.now();
    if (sessions.isEmpty) {
      return const Center(child: Text("لا توجد حصص في هذا اليوم", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final bool isEnded = session.endTime.isBefore(now);
        final bool isLive = session.isLive && !isEnded;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: isEnded ? Colors.grey.shade50 : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLive ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLive ? Icons.sensors : (isEnded ? Icons.history : Icons.book),
                color: isLive ? Colors.red : (isEnded ? Colors.grey : Colors.blue),
              ),
            ),
            title: Text(
              session.subjectName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: isEnded ? TextDecoration.lineThrough : null,
                color: isEnded ? Colors.grey : Colors.black87,
              ),
            ),
            subtitle: Text("${DateFormat('hh:mm a').format(session.startTime)} - ${session.teacherName}"),
            trailing: isLive
                ? _buildLiveBadge()
                : (isEnded ? const Text("منتهية", style: TextStyle(color: Colors.grey, fontSize: 12)) : const Icon(Icons.arrow_forward_ios, size: 14)),
            onTap: isLive ? () => _joinSession(session) : null,
          ),
        );
      },
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
      child: const Text("مباشر", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  void _joinSession(SessionModel session) {
    final user = supabase.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? "الطالب";
    Navigator.push(context, MaterialPageRoute(builder: (context) => VideoRoomScreen(title: "بث مباشر: ${session.subjectName}", roomName: "room_${session.id}", userName: userName)));
  }
}
