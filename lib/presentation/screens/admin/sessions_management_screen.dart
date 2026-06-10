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
    final bool isDesktop = Responsive.isDesktop(context);
    
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
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
            child: StatefulBuilder(
              builder: (context, setSheetState) => SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isEditing ? "تعديل بيانات الحصة" : "جدولة حصة جديدة", 
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: subjectController,
                      style: const TextStyle(fontFamily: 'Cairo'),
                      decoration: InputDecoration(
                        labelText: "اسم المادة", 
                        prefixIcon: const Icon(Icons.book_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController,
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, letterSpacing: 2),
                      decoration: InputDecoration(
                        labelText: "كود الحصة",
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.bolt_rounded, color: Colors.orange),
                          onPressed: () => setSheetState(() => codeController.text = _generateRandomCode()),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedTeacherId,
                      style: const TextStyle(fontFamily: 'Cairo', color: Colors.black),
                      decoration: InputDecoration(
                        labelText: "تعيين المدرس", 
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
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
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            icon: const Icon(Icons.calendar_today_rounded),
                            label: Text(DateFormat('yyyy/MM/dd').format(selectedDate), style: const TextStyle(fontFamily: 'Cairo')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final time = await showTimePicker(context: context, initialTime: selectedTime);
                              if (time != null) setSheetState(() => selectedTime = time);
                            },
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            icon:  const Icon(Icons.access_time_rounded),
                            label: Text(selectedTime.format(context).replaceAll("AM", "صباحاً").replaceAll("PM", "مساءً"), style: const TextStyle(fontFamily: 'Cairo')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF102A43),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (subjectController.text.isEmpty || selectedTeacherId == null) return;
                          
                          final startLocal = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                          final endLocal = startLocal.add(Duration(minutes: selectedDuration));

                          final dbService = Provider.of<DatabaseService>(context, listen: false);
                          await dbService.saveSession({
                            'subject_name': subjectController.text.trim(),
                            'class_code': codeController.text.trim().toUpperCase(),
                            'teacher_id': selectedTeacherId,
                            'start_time': startLocal.toUtc().toIso8601String(),
                            'end_time': endLocal.toUtc().toIso8601String(),
                          }, id: session?['id']);

                          if (mounted) {
                            Navigator.pop(context);
                            _fetchData();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات الحصة بنجاح ✅', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                          }
                        },
                        child: Text(isEditing ? "تحديث الحصة" : "إنشاء الحصة الآن", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("إدارة الحصص التعليمية", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: isMobile,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(onPressed: _fetchData, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
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
      floatingActionButton: isMobile 
          ? FloatingActionButton(
              onPressed: () => _showSessionSheet(),
              backgroundColor: const Color(0xFF102A43),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    final bool isMobile = Responsive.isMobile(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isMobile ? 15 : 25),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("جدول الحصص المجدولة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              SizedBox(height: 4),
              Text("عرض وإدارة كافة المواعيد الدراسية في المنصة", style: TextStyle(fontSize: 13, color: Colors.blueGrey, fontFamily: 'Cairo')),
            ],
          ),
          if (!isMobile)
            ElevatedButton.icon(
              onPressed: () => _showSessionSheet(),
              icon: const Icon(Icons.add_rounded),
              label: const Text("إضافة حصة جديدة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF102A43),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      margin: const EdgeInsets.all(30),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 5))]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: DataTable(
            horizontalMargin: 24,
            columnSpacing: 30,
            headingRowHeight: 70,
            dataRowMaxHeight: 75,
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8F9FB)),
            headingTextStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black87),
            columns: const [
              DataColumn(label: Text('المادة الدراسية')),
              DataColumn(label: Text('المدرس')),
              DataColumn(label: Text('كود الدخول')),
              DataColumn(label: Text('الموعد المقرر')),
              DataColumn(label: Text('الإجراءات')),
            ],
            rows: _sessions.map((session) {
              final startTime = DateTime.parse(session['start_time']).toLocal();
              String timeStr = DateFormat('hh:mm').format(startTime) + (startTime.hour < 12 ? " صباحاً" : " مساءً");
              return DataRow(cells: [
                DataCell(Text(session['subject_name'], style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 15))),
                DataCell(Row(
                  children: [
                    CircleAvatar(radius: 14, backgroundColor: Colors.blue.shade50, child: const Icon(Icons.person, size: 16, color: Colors.blue)),
                    const SizedBox(width: 10),
                    Text(session['profiles']?['full_name'] ?? '---', style: const TextStyle(fontFamily: 'Cairo')),
                  ],
                )),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(session['class_code'], style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                )),
                DataCell(Text("${DateFormat('yyyy/MM/dd').format(startTime)} | $timeStr", style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(tooltip: "تعديل", onPressed: () => _showSessionSheet(session: session), icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 26)),
                    IconButton(tooltip: "حذف", onPressed: () => _confirmDelete(session['id']), icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 24)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("حذف الحصة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      content: const Text("هل أنت متأكد من حذف هذه الحصة نهائياً؟ لن يتمكن الطلاب من الدخول إليها مجدداً.", style: TextStyle(fontFamily: 'Cairo')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
        ElevatedButton(
          onPressed: () async {
            await Provider.of<DatabaseService>(context, listen: false).deleteSession(id);
            if (mounted) { Navigator.pop(context); _fetchData(); }
          }, 
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
          child: const Text("حذف الحصة", style: TextStyle(fontFamily: 'Cairo', color: Colors.white))
        ),
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
        String timeStr = DateFormat('hh:mm').format(startTime) + (startTime.hour < 12 ? " صباحاً" : " مساءً");
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade100)),
          margin: const EdgeInsets.only(bottom: 15),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ListTile(
              leading: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: const Color(0xFF102A43).withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.class_rounded, color: Color(0xFF102A43)),
              ),
              title: Text(session['subject_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text("أ. ${session['profiles']?['full_name']}", style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                  Text("${DateFormat('dd/MM').format(startTime)} الساعة $timeStr", style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.grey)),
                ],
              ),
              trailing: PopupMenuButton(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                itemBuilder: (context) => [
                  PopupMenuItem(child: const ListTile(leading: Icon(Icons.edit_note), title: Text("تعديل", style: TextStyle(fontFamily: 'Cairo'))), onTap: () => Future.delayed(Duration.zero, () => _showSessionSheet(session: session))),
                  PopupMenuItem(child: const ListTile(leading: Icon(Icons.delete_sweep, color: Colors.red), title: Text("حذف", style: TextStyle(color: Colors.red, fontFamily: 'Cairo'))), onTap: () => Future.delayed(Duration.zero, () => _confirmDelete(session['id']))),
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
    child: ListView.builder(padding: const EdgeInsets.all(20), itemCount: 6, itemBuilder: (_, __) => Container(height: 85, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
  );

  Widget _buildErrorState() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.error_outline_rounded, size: 70, color: Colors.redAccent),
      const SizedBox(height: 16),
      Text(_error ?? "حدث خطأ غير متوقع", style: const TextStyle(fontSize: 16, fontFamily: 'Cairo')),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _fetchData, 
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF102A43)),
        child: const Text("إعادة المحاولة", style: TextStyle(fontFamily: 'Cairo', color: Colors.white))
      ),
    ],
  ));
}
