import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/attendance_pdf_service.dart';
import '../../../../core/utils/responsive.dart';

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
      final enrollmentsRes = await supabase
          .from('enrollments')
          .select('student_id, profiles:student_id(full_name)')
          .eq('session_id', widget.sessionId);

      final attendanceRes = await supabase
          .from('attendance')
          .select('student_id, status, joined_at, left_at, total_duration_minutes, profiles:student_id(full_name)')
          .eq('session_id', widget.sessionId);

      final List<dynamic> enrollments = enrollmentsRes as List;
      final List<dynamic> attendanceList = attendanceRes as List;

      final Map<String, Map<String, dynamic>> studentsMap = {};

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
          SnackBar(content: Text("خطأ أثناء إنشاء ملف PDF: $e", style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ كشف الحضور بنجاح ✅', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int presentCount = _students.where((s) => s['present'] == true).length;
    int total = _students.length;
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text("تحضير ${widget.subjectName}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo')),
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (!_isLoading && _students.isNotEmpty) ...[
            IconButton(
              onPressed: _exportToPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent),
              tooltip: "تحميل التقرير PDF",
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              child: ElevatedButton.icon(
                onPressed: _saveAttendance,
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text("اعتماد الكشف", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF102A43),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ]
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildHeader(presentCount, total, isDesktop),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text("الطلاب المسجل دخولهم تلقائياً تظهر بيانات انضمامهم في تقرير PDF", style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _students.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: EdgeInsets.all(isDesktop ? 24 : 16),
                              itemCount: _students.length,
                              itemBuilder: (context, index) => _buildStudentTile(index),
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(int present, int total, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF102A43), Color(0xFF243B53)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF102A43).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("حالة الحضور اللحظية", style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Cairo')),
            const SizedBox(height: 8),
            Text("$present طالب حاضر من أصل $total", style: TextStyle(color: Colors.white, fontSize: isDesktop ? 24 : 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ]),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.groups_rounded, color: Colors.white, size: 40),
          ),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: isAuto ? Border.all(color: Colors.green.withOpacity(0.2), width: 1.5) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: isAuto ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
          child: Text(s['name'][0].toUpperCase(), style: TextStyle(color: isAuto ? Colors.green : Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: s['present'] ? Colors.green : Colors.red, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  isAuto ? "تم التحضير تلقائياً" : (s['present'] ? "حاضر" : "غائب"),
                  style: TextStyle(color: s['present'] ? Colors.green : Colors.red, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (isAuto && s['duration'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("مدة الحضور: ${s['duration']} دقيقة", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'Cairo')),
              ),
          ],
        ),
        trailing: Transform.scale(
          scale: 0.9,
          child: Switch(
            value: s['present'],
            activeColor: Colors.green,
            onChanged: (val) => setState(() => _students[index]['present'] = val),
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
          Icon(Icons.person_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("لا يوجد طلاب مسجلين حالياً", style: TextStyle(color: Colors.grey, fontSize: 16, fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}
