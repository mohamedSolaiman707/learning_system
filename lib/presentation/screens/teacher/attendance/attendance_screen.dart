import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceScreen extends StatefulWidget {
  final String sessionId;
  final String subjectName;

  const AttendanceScreen({
    super.key,
    required this.sessionId,
    required this.subjectName,
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
      final enrollments = await supabase
          .from('enrollments')
          .select('student_id, profiles:student_id(full_name)')
          .eq('session_id', widget.sessionId);

      // 2. جلب سجلات الحضور الحالية (التي سجلتها الـ Edge Function تلقائياً)
      final attendanceRecords = await supabase
          .from('attendance')
          .select('student_id, status')
          .eq('session_id', widget.sessionId);

      final List<dynamic> attendanceList = attendanceRecords as List;

      if (enrollments != null) {
        setState(() {
          _students = (enrollments as List).map((e) {
            final profile = e['profiles'] as Map<String, dynamic>?;
            final studentId = e['student_id'];
            
            // التحقق مما إذا كان الطالب قد تم تحضيره تلقائياً
            final record = attendanceList.firstWhere(
              (r) => r['student_id'] == studentId, 
              orElse: () => null
            );

            return {
              'id': studentId,
              'name': profile != null ? profile['full_name'] : "طالب غير معروف",
              'present': record != null && record['status'] == 'present', 
              'isAutoMarked': record != null, // علامة تدل على أنه حضر من مودل
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Attendance Load Error: $e");
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

      // استخدام upsert لتحديث السجلات الموجودة أو إضافة جديدة
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
          if (!_isLoading && _students.isNotEmpty)
            TextButton.icon(
              onPressed: _saveAttendance,
              icon: const Icon(Icons.done_all),
              label: const Text("اعتماد الكشف"),
            )
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
                      Text("الطلاب المفعلين باللون الأخضر تم تحضيرهم تلقائياً من مودل", style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
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
          const Icon(IconlyBold.user_3, color: Colors.white24, size: 40),
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
        subtitle: Text(
          isAuto ? "تم التحضير تلقائياً من Moodle" : (s['present'] ? "حاضر" : "غائب"),
          style: TextStyle(color: s['present'] ? Colors.green : Colors.red, fontSize: 11),
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
    return const Center(child: Text("لا يوجد طلاب مسجلين في هذه الحصة"));
  }
}
