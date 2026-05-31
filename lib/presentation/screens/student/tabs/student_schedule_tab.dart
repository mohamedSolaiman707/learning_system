import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/models/session_model.dart';
import '../../video_room/video_room_screen.dart';

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
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      final data = await db.getStudentSchedule(auth.user!.id);
      
      if (mounted) {
        setState(() {
          _allSessions = data.map((e) => SessionModel.fromMap(e['sessions'])).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showJoinCodeDialog() {
    final codeController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("انضمام لحصة جديدة", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("أدخل كود الحصة للانضمام إلى جدولك", 
                style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 4),
                decoration: InputDecoration(
                  hintText: "ABC123",
                  hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 4),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (codeController.text.isEmpty) return;
                
                setDialogState(() => isSubmitting = true);
                try {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final db = Provider.of<DatabaseService>(context, listen: false);
                  
                  await db.enrollStudentByCode(auth.user!.id, codeController.text);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("تم الانضمام للحصة بنجاح"), backgroundColor: Colors.green)
                    );
                    _loadSchedule();
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.red)
                  );
                }
              },
              child: isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("انضمام"),
            ),
          ],
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
        title: const Text("جدول حصصي"),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showJoinCodeDialog,
            icon: const Icon(IconlyLight.plus),
            tooltip: "انضمام بكود",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _loadSchedule,
              child: Responsive(
                mobile: _buildMobileLayout(),
                desktop: _buildDesktopLayout(),
              ),
            ),
      floatingActionButton: Responsive.isMobile(context) 
        ? FloatingActionButton.extended(
            onPressed: _showJoinCodeDialog,
            icon: const Icon(IconlyLight.plus),
            label: const Text("انضمام بكود"),
          )
        : null,
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildCalendarCard(),
        Expanded(
          child: _buildSessionsList(_getSessionsForDay(_selectedDay!)),
        ),
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
            padding: const EdgeInsets.all(20),
            child: _buildCalendarCard(),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: _buildSessionsList(_getSessionsForDay(_selectedDay!)),
        ),
      ],
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
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
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(color: Colors.lightBlueAccent, shape: BoxShape.circle),
          selectedDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
          markerDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
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
            Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("لا توجد حصص في هذا اليوم", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _showJoinCodeDialog,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue, elevation: 0),
              child: const Text("انضم لحصة الآن"),
            ),
          ],
        ),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userName = authProvider.profile?['full_name'] ?? "Student";
    final userId = authProvider.user?.id ?? "";

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isLive = session.isLive;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isLive ? Colors.red : Colors.blue).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLive ? Icons.sensors : Icons.book_outlined,
                color: isLive ? Colors.red : Colors.blue,
              ),
            ),
            title: Text(session.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("مع: ${session.teacherName}"),
                Text(DateFormat('hh:mm a').format(session.startTime), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            trailing: isLive 
              ? ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => VideoRoomScreen(
                        title: session.subjectName,
                        roomName: "room_${session.id}",
                        userName: userName,
                        userId: userId, // تمرير الـ UUID الجديد
                        isTeacher: false,
                        sessionId: session.id,
                      ),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(80, 40),
                  ),
                  child: const Text("دخول"),
                )
              : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: [
          Container(height: 350, margin: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 3,
              itemBuilder: (_, __) => Container(height: 100, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
            ),
          ),
        ],
      ),
    );
  }
}
