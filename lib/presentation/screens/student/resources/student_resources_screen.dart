import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/resource_model.dart';
import '../../../../core/services/resources_service.dart';

class StudentResourcesScreen extends StatefulWidget {
  final String sessionId;
  final String subjectName;

  const StudentResourcesScreen({
    super.key,
    required this.sessionId,
    required this.subjectName,
  });

  @override
  State<StudentResourcesScreen> createState() => _StudentResourcesScreenState();
}

class _StudentResourcesScreenState extends State<StudentResourcesScreen> {
  final _resourcesService = ResourcesService();
  List<ResourceModel> _resources = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() => _isLoading = true);
    final data = await _resourcesService.getResources(widget.sessionId);
    setState(() {
      _resources = data;
      _isLoading = false;
    });
  }

  Future<void> _downloadResource(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تعذر فتح الرابط")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: Text("مصادر $widget.subjectName")),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(_getFileIcon(res.fileType), color: Colors.blue),
                        ),
                        title: Text(res.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(res.fileType.toUpperCase(), style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(IconlyLight.download, color: Colors.grey),
                          onPressed: () => _downloadResource(res.fileUrl),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(IconlyLight.folder, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("لا توجد ملفات مرفوعة لهذه المادة حتى الآن", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'jpg': case 'jpeg': case 'png': return Icons.image;
      case 'mp4': case 'mov': return Icons.video_library;
      default: return Icons.insert_drive_file;
    }
  }
}
