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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('sessions')
          .select('*, profiles:teacher_id(full_name)')
          .order('start_time', ascending: false);
      
      setState(() {
        _sessions = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSession(String id) async {
    try {
      await supabase.from('sessions').delete().eq('id', id);
      _fetchSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الحصة بنجاح')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء الحذف: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة الحصص والجلسات"),
        actions: [
          IconButton(onPressed: _fetchSessions, icon: const Icon(IconlyLight.swap)),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
            ? const Center(child: Text("لا توجد حصص مسجلة حالياً"))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  final startTime = DateTime.parse(session['start_time']);
                  final teacherName = session['profiles']?['full_name'] ?? 'غير معروف';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(IconlyLight.video, color: Colors.blue),
                      ),
                      title: Text(
                        session['subject_name'] ?? 'بدون عنوان',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("المدرس: $teacherName"),
                          Text("الموعد: ${DateFormat('yyyy/MM/dd - hh:mm a').format(startTime)}"),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(IconlyLight.edit, color: Colors.blue),
                            onPressed: () {
                              // هنا يمكن إضافة واجهة لتعديل الحصة
                            },
                          ),
                          IconButton(
                            icon: const Icon(IconlyLight.delete, color: Colors.red),
                            onPressed: () => _showDeleteDialog(session['id'], session['subject_name']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // هنا يمكن إضافة واجهة لإنشاء حصة جديدة
        },
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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSession(id);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
