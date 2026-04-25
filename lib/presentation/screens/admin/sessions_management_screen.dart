import 'dart:math';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SessionsManagementScreen extends StatefulWidget {
  const SessionsManagementScreen({super.key});

  @override
  State<SessionsManagementScreen> createState() => _SessionsManagementScreenState();
}

class _SessionsManagementScreenState extends State<SessionsManagementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchSessions(), _fetchTeachers()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchSessions() async {
    try {
      final response = await supabase
          .from('sessions')
          .select('*, profiles:teacher_id(full_name)')
          .order('start_time', ascending: false);
      _sessions = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
    }
  }

  Future<void> _fetchTeachers() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'teacher');
      _teachers = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching teachers: $e');
    }
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _saveSession({String? id, required Map<String, dynamic> data}) async {
    try {
      if (id == null) {
        await supabase.from('sessions').insert(data);
      } else {
        await supabase.from('sessions').update(data).eq('id', id);
      }
      _fetchSessions();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(id == null ? 'تمت إضافة الحصة بنجاح' : 'تم تحديث الحصة بنجاح')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _deleteSession(String id) async {
    try {
      await supabase.from('sessions').delete().eq('id', id);
      _fetchSessions();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الحصة بنجاح')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحذف: $e')));
    }
  }

  void _showSessionSheet({Map<String, dynamic>? session}) {
    final isEditing = session != null;
    final subjectController = TextEditingController(text: session?['subject_name']);
    final codeController = TextEditingController(text: session?['class_code']);
    String? selectedTeacherId = session?['teacher_id'];
    DateTime selectedDate = isEditing ? DateTime.parse(session['start_time']).toLocal() : DateTime.now();
    TimeOfDay selectedTime = isEditing ? TimeOfDay.fromDateTime(DateTime.parse(session['start_time']).toLocal()) : TimeOfDay.now();
    int selectedDuration = 60;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEditing ? "تعديل الحصة" : "إضافة حصة جديدة", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: "اسم المادة", prefixIcon: Icon(IconlyLight.document)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: "كود الحصة",
                  prefixIcon: const Icon(IconlyLight.password),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.bolt, color: Colors.orange),
                    onPressed: () => setSheetState(() => codeController.text = _generateRandomCode()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedTeacherId,
                decoration: const InputDecoration(labelText: "اختر المدرس", prefixIcon: Icon(IconlyLight.user_1)),
                items: _teachers.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['full_name']))).toList(),
                onChanged: (val) => setSheetState(() => selectedTeacherId = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedDuration,
                decoration: const InputDecoration(labelText: "مدة الحصة", prefixIcon: Icon(IconlyLight.time_circle)),
                items: const [
                  DropdownMenuItem(value: 30, child: Text("30 دقيقة")),
                  DropdownMenuItem(value: 60, child: Text("ساعة واحدة")),
                  DropdownMenuItem(value: 90, child: Text("ساعة ونصف")),
                  DropdownMenuItem(value: 120, child: Text("ساعتين")),
                ],
                onChanged: (val) => setSheetState(() => selectedDuration = val!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                        if (date != null) setSheetState(() => selectedDate = date);
                      },
                      icon: const Icon(IconlyLight.calendar),
                      label: Text(DateFormat('yyyy/MM/dd').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(context: context, initialTime: selectedTime);
                        if (time != null) setSheetState(() => selectedTime = time);
                      },
                      icon: const Icon(IconlyLight.time_circle),
                      label: Text(selectedTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (subjectController.text.isEmpty || selectedTeacherId == null) return;
                  // تحويل الوقت المختار إلى UTC قبل الحفظ لضمان الدقة
                  final startLocal = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                  final endLocal = startLocal.add(Duration(minutes: selectedDuration));

                  _saveSession(
                    id: session?['id'],
                    data: {
                      'subject_name': subjectController.text,
                      'class_code': codeController.text.trim().toUpperCase(),
                      'teacher_id': selectedTeacherId,
                      'start_time': startLocal.toUtc().toIso8601String(),
                      'end_time': endLocal.toUtc().toIso8601String(),
                    },
                  );
                  Navigator.pop(context);
                },
                child: Text(isEditing ? "تحديث البيانات" : "إنشاء الحصة الآن"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة الحصص والجلسات"),
        actions: [IconButton(onPressed: _fetchData, icon: const Icon(IconlyLight.swap))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          final startTime = DateTime.parse(session['start_time']).toLocal();
          final endTime = DateTime.parse(session['end_time']).toLocal();
          final duration = endTime.difference(startTime).inMinutes;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(IconlyLight.video, color: Colors.blue),
              ),
              title: Text(session['subject_name'] ?? 'بدون عنوان', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text("المدرس: ${session['profiles']?['full_name']}\nالمدة: $duration دقيقة\nالموعد: ${DateFormat('hh:mm a').format(startTime)}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(IconlyLight.edit, color: Colors.blue), onPressed: () => _showSessionSheet(session: session)),
                  IconButton(icon: const Icon(IconlyLight.delete, color: Colors.red), onPressed: () => _showDeleteDialog(session['id'], session['subject_name'])),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSessionSheet(),
        label: const Text("إضافة حصة جديدة"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteDialog(String id, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد من حذف حصة $title؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(onPressed: () { Navigator.pop(context); _deleteSession(id); }, child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
