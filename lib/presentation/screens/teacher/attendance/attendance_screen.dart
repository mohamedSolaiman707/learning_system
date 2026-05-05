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

  // جلب الطلاب المسجلين في الحصة
  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('enrollments')
          .select('student_id, profiles:student_id(full_name)')
          .eq('session_id', widget.sessionId);

      if (response != null) {
        setState(() {
          _students = (response as List).map((e) {
            final profile = e['profiles'] as Map<String, dynamic>?;
            return {
              'id': e['student_id'],
              'name': profile != null ? profile['full_name'] : "طالب غير معروف",
              'present': true, 
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

  // إضافة طالب يدوي للحصة (Enrollment)
  Future<void> _manualEnroll() async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("إضافة طالب للحصة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "ابحث باسم الطالب أو الإيميل...",
                  prefixIcon: const Icon(IconlyLight.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      if (searchController.text.length < 3) return;
                      setModalState(() => isSearching = true);
                      try {
                        final res = await supabase.from('profiles')
                            .select()
                            .eq('role', 'student')
                            .ilike('full_name', '%${searchController.text}%');
                        setModalState(() {
                          searchResults = List<Map<String, dynamic>>.from(res);
                          isSearching = false;
                        });
                      } catch (e) {
                        setModalState(() => isSearching = false);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (isSearching) const LinearProgressIndicator(),
              SizedBox(
                height: 300,
                child: searchResults.isEmpty 
                  ? const Center(child: Text("لا توجد نتائج"))
                  : ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, i) {
                        final student = searchResults[i];
                        bool isAlreadyIn = _students.any((s) => s['id'] == student['id']);
                        return ListTile(
                          title: Text(student['full_name']),
                          subtitle: Text(student['email'] ?? ""),
                          trailing: isAlreadyIn 
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await supabase.from('enrollments').insert({
                                      'student_id': student['id'],
                                      'session_id': widget.sessionId,
                                    });
                                    Navigator.pop(context);
                                    _loadStudents(); // إعادة تحميل الكشف
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل إضافة الطالب")));
                                  }
                                },
                                child: const Text("إضافة"),
                              ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAttendance() async {
    if (_students.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final date = DateTime.now().toIso8601String().split('T')[0];
      final List<Map<String, dynamic>> attendanceData = _students.map((s) => {
        'session_id': widget.sessionId,
        'student_id': s['id'],
        'status': s['present'] ? 'present' : 'absent',
        'date': date,
      }).toList();

      await supabase.from('attendance').upsert(attendanceData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الحضور بنجاح ✅'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
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
          IconButton(onPressed: _manualEnroll, icon: const Icon(Icons.person_outline, color: Colors.blue), tooltip: "إضافة طالب يدوي"),
          if (!_isLoading && _students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _saveAttendance,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("حفظ"),
              ),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(presentCount, total),
                Expanded(
                  child: _students.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: _students.length,
                          itemBuilder: (context, index) => _buildStudentTile(index),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(IconlyLight.user_1, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text("لا يوجد طلاب مسجلين. استخدم زر 👨‍💼 لإضافة طلاب.", style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 20),
          ElevatedButton.icon(onPressed: _manualEnroll, icon: const Icon(Icons.person_outline), label: const Text("إضافة طلاب الآن"))
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
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("نسبة الحضور اليوم", style: TextStyle(color: Colors.white70, fontSize: 14)),
            Text("$present من $total طلاب", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
          const Icon(IconlyBold.user_3, color: Colors.white24, size: 40),
        ],
      ),
    );
  }

  Widget _buildStudentTile(int index) {
    final s = _students[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: Text(s['name'][0].toUpperCase(), style: const TextStyle(color: Colors.blue))),
        title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(s['present'] ? "حاضر" : "غائب", style: TextStyle(color: s['present'] ? Colors.green : Colors.red, fontSize: 12)),
        trailing: Switch(
          value: s['present'],
          activeColor: Colors.green,
          onChanged: (val) => setState(() => _students[index]['present'] = val),
        ),
      ),
    );
  }
}
