import 'dart:math';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/database_service.dart';

class SessionsManagementScreen extends StatefulWidget {
  const SessionsManagementScreen({super.key});

  @override
  State<SessionsManagementScreen> createState() => _SessionsManagementScreenState();
}

class _SessionsManagementScreenState extends State<SessionsManagementScreen> {
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final results = await Future.wait([
        dbService.getAllSessions(),
        dbService.getTeachersOnly(),
      ]);
      
      if (mounted) {
        setState(() {
          _sessions = results[0];
          _teachers = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "فشل تحميل البيانات";
          _isLoading = false;
        });
      }
    }
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEditing ? "تعديل الحصة" : "إضافة حصة جديدة", 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 24),
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                        if (date != null) setSheetState(() => selectedDate = date);
                      },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(IconlyLight.calendar),
                      label: Text(DateFormat('yyyy/MM/dd').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(context: context, initialTime: selectedTime);
                        if (time != null) setSheetState(() => selectedTime = time);
                      },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(IconlyLight.time_circle),
                      label: Text(selectedTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  if (subjectController.text.isEmpty || selectedTeacherId == null) return;
                  final startLocal = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                  final endLocal = startLocal.add(Duration(minutes: selectedDuration));

                  final dbService = Provider.of<DatabaseService>(context, listen: false);
                  await dbService.saveSession({
                    'subject_name': subjectController.text,
                    'class_code': codeController.text.trim().toUpperCase(),
                    'teacher_id': selectedTeacherId,
                    'start_time': startLocal.toUtc().toIso8601String(),
                    'end_time': endLocal.toUtc().toIso8601String(),
                  }, id: session?['id']);

                  if (mounted) {
                    Navigator.pop(context);
                    _fetchData();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ البيانات بنجاح'), backgroundColor: Colors.green));
                  }
                },
                child: Text(isEditing ? "تحديث الحصة" : "إنشاء الحصة"),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("إدارة الحصص"),
        actions: [
          IconButton(onPressed: _fetchData, icon: const Icon(IconlyLight.swap)),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading 
                ? _buildLoadingState()
                : _error != null 
                    ? _buildErrorState()
                    : Responsive(
                        mobile: _buildMobileList(),
                        desktop: _buildDesktopTable(),
                      ),
          ),
        ],
      ),
      floatingActionButton: Responsive.isMobile(context) 
          ? FloatingActionButton(onPressed: () => _showSessionSheet(), child: const Icon(Icons.add))
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("جدول الحصص الجارية", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("يمكنك إضافة أو تعديل مواعيد الدروس هنا", style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          if (!Responsive.isMobile(context))
            ElevatedButton.icon(
              onPressed: () => _showSessionSheet(),
              icon: const Icon(Icons.add),
              label: const Text("إضافة حصة جديدة"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(180, 54)),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('المادة')),
            DataColumn(label: Text('المدرس')),
            DataColumn(label: Text('الكود')),
            DataColumn(label: Text('الموعد')),
            DataColumn(label: Text('الإجراءات')),
          ],
          rows: _sessions.map((session) {
            final startTime = DateTime.parse(session['start_time']).toLocal();
            return DataRow(cells: [
              DataCell(Text(session['subject_name'], style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(session['profiles']?['full_name'] ?? '---')),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                child: Text(session['class_code'], style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              )),
              DataCell(Text(DateFormat('yyyy/MM/dd - hh:mm a').format(startTime))),
              DataCell(Row(
                children: [
                  IconButton(onPressed: () => _showSessionSheet(session: session), icon: const Icon(IconlyLight.edit, color: Colors.blue, size: 20)),
                  IconButton(onPressed: () {}, icon: const Icon(IconlyLight.delete, color: Colors.red, size: 20)),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final startTime = DateTime.parse(session['start_time']).toLocal();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(session['subject_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${session['profiles']?['full_name']} | ${DateFormat('hh:mm a').format(startTime)}"),
            trailing: IconButton(onPressed: () => _showSessionSheet(session: session), icon: const Icon(IconlyLight.edit)),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() => Shimmer.fromColors(
    baseColor: Colors.grey.shade300,
    highlightColor: Colors.grey.shade100,
    child: ListView.builder(padding: const EdgeInsets.all(20), itemCount: 6, itemBuilder: (_, __) => Container(height: 80, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)))),
  );

  Widget _buildErrorState() => Center(child: Text(_error ?? "حدث خطأ"));
}
