import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/attendance_pdf_service.dart';

class AttendanceScreen extends StatefulWidget {
  final String sessionId;
  final String subjectName;
  final String? teacherName;

  const AttendanceScreen({
    super.key,
    required this.sessionId,
    required this.subjectName,
    this.teacherName,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      // 1. جلب جميع الطلاب المسجلين في هذه الحصة
      final enrollmentsRes = await supabase
          .from('enrollments')
          .select('student_id, profiles:student_id(full_name)')
          .eq('session_id', widget.sessionId);

      // 2. جلب سجلات الحضور الحالية (التي سجلتها الـ VideoRoomScreen تلقائياً)
      final attendanceRes = await supabase
          .from('attendance')
          .select('student_id, status, joined_at, left_at, total_duration_minutes, profiles:student_id(full_name)')
          .eq('session_id', widget.sessionId);

      final List<dynamic> enrollments = enrollmentsRes as List;
      final List<dynamic> attendanceList = attendanceRes as List;

      // دمج البيانات لضمان ظهور كل من سجل أو حضر
      final Map<String, Map<String, dynamic>> studentsMap = {};

      // إضافة المسجلين أولاً
      for (var e in enrollments) {
        final studentId = e['student_id'];
        final profile = e['profiles'] as Map<String, dynamic>?;
        studentsMap[studentId] = {
          'id': studentId,
          'name': profile?['full_name'] ?? "طالب غير معروف",
          'present': false,
          'joined_at': null,
          'left_at': null,
          'duration': null,
          'isAutoMarked': false,
        };
      }

      // إضافة أو تحديث بيانات من حضروا فعلياً
      for (var a in attendanceList) {
        final studentId = a['student_id'];
        final profile = a['profiles'] as Map<String, dynamic>?;
        
        if (studentsMap.containsKey(studentId)) {
          studentsMap[studentId]!['present'] = a['status'] == 'present';
          studentsMap[studentId]!['joined_at'] = a['joined_at'];
          studentsMap[studentId]!['left_at'] = a['left_at'];
          studentsMap[studentId]!['duration'] = a['total_duration_minutes'];
          studentsMap[studentId]!['isAutoMarked'] = true;
        } else {
          // طالب حضر ولكنه غير مسجل في الحصة (دخل عبر رابط مباشر مثلاً)
          studentsMap[studentId] = {
            'id': studentId,
            'name': profile?['full_name'] ?? "طالب زائر",
            'present': a['status'] == 'present',
            'joined_at': a['joined_at'],
            'left_at': a['left_at'],
            'duration': a['total_duration_minutes'],
            'isAutoMarked': true,
          };
        }
      }

      setState(() {
        _students = studentsMap.values.toList();
        // ترتيب القائمة: الحاضرون أولاً ثم أبجدياً
        _students.sort((a, b) {
          if (a['present'] != b['present']) return b['present'] ? 1 : -1;
          return a['name'].compareTo(b['name']);
        });
      });
      
    } catch (e) {
      debugPrint("Attendance Load Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToPdf() async {
    if (_students.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final pdfService = AttendancePdfService();
      await pdfService.generateReport(
        subjectName: widget.subjectName,
        teacherName: widget.teacherName ?? "مدرس المادة",
        studentsData: _students,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ أثناء إنشاء ملف PDF: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendance() async {
    if (_students.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> attendanceData = _students.map((s) => {
        'session_id': widget.sessionId,
        'student_id': s['id'],
        'status': s['present'] ? 'present' : 'absent',
      }).toList();

      await supabase.from('attendance').upsert(attendanceData, onConflict: 'session_id,student_id');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ كشف الحضور بنجاح ✅'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int presentCount = _students.where((s) => s['present'] == true).length;
    int total = _students.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text("تحضير ${widget.subjectName}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (!_isLoading && _students.isNotEmpty) ...[
            IconButton(
              onPressed: _exportToPdf,
              icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              tooltip: "تحميل التقرير PDF",
            ),
            TextButton.icon(
              onPressed: _saveAttendance,
              icon: const Icon(Icons.done_all),
              label: const Text("اعتماد الكشف"),
            ),
          ]
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(presentCount, total),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text("الطلاب المسجل دخولهم تلقائياً تظهر بيانات انضمامهم في تقرير PDF", style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                    ],
                  ),
                ),
                Expanded(
                  child: _students.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _students.length,
                          itemBuilder: (context, index) => _buildStudentTile(index),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(int present, int total) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1976D2)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("حالة الحضور اللحظية", style: TextStyle(color: Colors.white70, fontSize: 14)),
            Text("$present طالب حاضر من أصل $total", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const Icon(IconlyBold.user3, color: Colors.white24, size: 40),
        ],
      ),
    );
  }

  Widget _buildStudentTile(int index) {
    final s = _students[index];
    final bool isAuto = s['isAutoMarked'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16),
        border: isAuto ? Border.all(color: Colors.green.withOpacity(0.3), width: 2) : null,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAuto ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
          child: Text(s['name'][0].toUpperCase(), style: TextStyle(color: isAuto ? Colors.green : Colors.blue)),
        ),
        title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAuto ? "تم التحضير تلقائياً" : (s['present'] ? "حاضر" : "غائب"),
              style: TextStyle(color: s['present'] ? Colors.green : Colors.red, fontSize: 11),
            ),
            if (isAuto && s['duration'] != null)
              Text("المدة: ${s['duration']} دقيقة", style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        trailing: Switch(
          value: s['present'],
          activeColor: Colors.green,
          onChanged: (val) => setState(() => _students[index]['present'] = val),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text("لا يوجد طلاب مسجلين أو حاضرين في هذه الحصة"));
  }
}
