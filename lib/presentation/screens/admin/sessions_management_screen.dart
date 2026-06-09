import 'dart:math';
import 'package:flutter/material.dart';
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
    
    DateTime selectedDate = isEditing 
        ? DateTime.parse(session['start_time']).toLocal() 
        : DateTime.now();
    TimeOfDay selectedTime = isEditing 
        ? TimeOfDay.fromDateTime(DateTime.parse(session['start_time']).toLocal()) 
        : TimeOfDay.now();
    int selectedDuration = 60;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600), // تحديد عرض أقصى للـ Sheet في الديسكتوب
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
                  decoration: const InputDecoration(labelText: "اسم المادة", prefixIcon: Icon(Icons.description_outlined)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: "كود الحصة",
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.bolt, color: Colors.orange),
                      onPressed: () => setSheetState(() => codeController.text = _generateRandomCode()),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedTeacherId,
                  decoration:  const InputDecoration(labelText: "اختر المدرس", prefixIcon: Icon(Icons.person_outline)),
                  items: _teachers.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['full_name']))).toList(),
                  onChanged: (val) => setSheetState(() => selectedTeacherId = val),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365)));
                          if (date != null) setSheetState(() => selectedDate = date);
                        },
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.calendar_today_outlined),
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
                        icon:  const Icon(Icons.access_time_outlined),
                        label: Text(selectedTime.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
                      child: Text(isEditing ? "تحديث الحصة" : "إنشاء الحصة", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
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
        centerTitle: Responsive.isMobile(context),
        actions: [
          IconButton(onPressed: _fetchData, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200), // تحديد عرض أقصى للمحتوى كله
          child: Column(
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
        ),
      ),
      floatingActionButton: Responsive.isMobile(context) 
          ? FloatingActionButton(onPressed: () => _showSessionSheet(), child: const Icon(Icons.add))
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("جدول الحصص الجارية", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text("سيتم عرض الأوقات بتوقيت مصر المحلي", style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ],
          ),
          if (!Responsive.isMobile(context))
            ElevatedButton.icon(
              onPressed: () => _showSessionSheet(),
              icon: const Icon(Icons.add),
              label: const Text("إضافة حصة جديدة"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(180, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      margin: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
            columns: const [
              DataColumn(label: Text('المادة', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('المدرس', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الكود', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الموعد', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الإجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _sessions.map((session) {
              final startTime = DateTime.parse(session['start_time']).toLocal();
              return DataRow(cells: [
                DataCell(Text(session['subject_name'], style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(session['profiles']?['full_name'] ?? '---')),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text(session['class_code'], style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.blue)),
                )),
                DataCell(Text(DateFormat('yyyy/MM/dd | hh:mm a').format(startTime))),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(tooltip: "تعديل", onPressed: () => _showSessionSheet(session: session), icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 22)),
                    IconButton(tooltip: "حذف", onPressed: () => _confirmDelete(session['id']), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22)),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("حذف الحصة"),
      content: const Text("هل أنت متأكد من حذف هذه الحصة نهائياً؟"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
        ElevatedButton(onPressed: () async {
          await Provider.of<DatabaseService>(context, listen: false).deleteSession(id);
          if (mounted) { Navigator.pop(context); _fetchData(); }
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("حذف")),
      ],
    ));
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final startTime = DateTime.parse(session['start_time']).toLocal();
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Container(
                width: 45, height: 45,
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.class_outlined, color: Colors.blue),
              ),
              title: Text(session['subject_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text("${session['profiles']?['full_name']}"),
                  Text(DateFormat('hh:mm a - yyyy/MM/dd').format(startTime), style: const TextStyle(fontSize: 12)),
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(child: const ListTile(leading: Icon(Icons.edit), title: Text("تعديل")), onTap: () => Future.delayed(Duration.zero, () => _showSessionSheet(session: session))),
                  PopupMenuItem(child: const ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text("حذف", style: TextStyle(color: Colors.red))), onTap: () => Future.delayed(Duration.zero, () => _confirmDelete(session['id']))),
                ],
              ),
            ),
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

  Widget _buildErrorState() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 16),
      Text(_error ?? "حدث خطأ ما", style: const TextStyle(fontSize: 16)),
      TextButton(onPressed: _fetchData, child: const Text("حاول مرة أخرى")),
    ],
  ));
}
