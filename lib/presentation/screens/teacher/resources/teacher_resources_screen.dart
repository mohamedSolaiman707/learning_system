import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class TeacherResourcesScreen extends StatefulWidget {
  final String sessionId;
  final String subjectName;

  const TeacherResourcesScreen({
    super.key,
    required this.sessionId,
    required this.subjectName,
  });

  @override
  State<TeacherResourcesScreen> createState() => _TeacherResourcesScreenState();
}

class _TeacherResourcesScreenState extends State<TeacherResourcesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _resources = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('resources')
          .select()
          .eq('session_id', widget.sessionId)
          .order('created_at', ascending: false);
      setState(() {
        _resources = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadResource() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx']);
    if (result == null) return;

    setState(() => _isLoading = true);
    try {
      final file = result.files.first;
      final fileName = "res_${DateTime.now().millisecondsSinceEpoch}_${file.name}";
      final filePath = 'resources/$fileName';

      // رفع الملف لـ Storage
      await supabase.storage.from('resources').upload(filePath, File(file.path!));
      final fileUrl = supabase.storage.from('resources').getPublicUrl(filePath);

      // حفظ بيانات الملف في Database
      await supabase.from('resources').insert({
        'session_id': widget.sessionId,
        'title': file.name,
        'file_url': fileUrl,
        'file_type': file.extension,
      });

      _loadResources();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم رفع الملف بنجاح ✅")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء الرفع: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text("المكتبة: ${widget.subjectName}"),
        actions: [
          IconButton(onPressed: _uploadResource, icon: const Icon(IconlyLight.upload)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _resources.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _resources.length,
                  itemBuilder: (context, index) {
                    final res = _resources[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: _buildFileIcon(res['file_type']),
                        title: Text(res['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${res['file_type']?.toString().toUpperCase()}"),
                        trailing: IconButton(
                          icon: const Icon(IconlyLight.show, color: Colors.blue),
                          onPressed: () => launchUrl(Uri.parse(res['file_url'])),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadResource,
        label: const Text("رفع ملف جديد"),
        icon: const Icon(IconlyLight.upload),
      ),
    );
  }

  Widget _buildFileIcon(String? type) {
    IconData icon = IconlyBold.document;
    Color color = Colors.blue;
    if (type == 'pdf') { icon = Icons.picture_as_pdf; color = Colors.red; }
    return CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(IconlyLight.folder, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("لا توجد ملفات في المكتبة حالياً", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
