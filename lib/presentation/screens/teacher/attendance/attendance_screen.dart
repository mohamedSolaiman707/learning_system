import 'package:flutter/material.dart';
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
      // جلب الطلاب المسجلين في هذه الحصة
      final response = await supabase
          .from('enrollments')
          .select('student_id, profiles:student_id(full_name)')
          .eq('session_id', widget.sessionId);

      setState(() {
        _students = (response as List).map((e) => {
          'id': e['student_id'],
          'name': e['profiles']['full_name'],
          'present': true, // الحالة الافتراضية
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading students: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> attendanceData = _students.map((s) => {
        'session_id': widget.sessionId,
        'student_id': s['id'],
        'status': s['present'] ? 'present' : 'absent',
      }).toList();

      await supabase.from('attendance').upsert(attendanceData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الحضور بنجاح')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("حضور: ${widget.subjectName}"),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveAttendance,
              child: const Text("حفظ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? const Center(child: Text("لا يوجد طلاب مسجلين في هذه الحصة"))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _students.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    return CheckboxListTile(
                      title: Text(student['name']),
                      subtitle: Text(student['present'] ? "حاضر" : "غائب"),
                      value: student['present'],
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (value) {
                        setState(() {
                          _students[index]['present'] = value;
                        });
                      },
                      secondary: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Text(student['name'][0]),
                      ),
                    );
                  },
                ),
    );
  }
}
