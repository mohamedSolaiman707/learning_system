import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/assignment_model.dart';
import '../../../../core/services/assignments_service.dart';
import 'teacher_submissions_screen.dart'; // استدعاء شاشة التسليمات

class TeacherAssignmentsScreen extends StatefulWidget {
  final String sessionId;
  final String subjectName;

  const TeacherAssignmentsScreen({
    super.key,
    required this.sessionId,
    required this.subjectName,
  });

  @override
  State<TeacherAssignmentsScreen> createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends State<TeacherAssignmentsScreen> {
  final _assignmentsService = AssignmentsService();
  List<AssignmentModel> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);
    final data = await _assignmentsService.getAssignments(widget.sessionId);
    setState(() {
      _assignments = data;
      _isLoading = false;
    });
  }

  void _showAddAssignmentSheet() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    PlatformFile? pickedFile;
    DateTime? selectedDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("إضافة واجب جديد", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "عنوان الواجب", prefixIcon: Icon(IconlyLight.document)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "وصف أو تعليمات", prefixIcon: Icon(IconlyLight.edit)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.pickFiles(withData: true);
                  if (result != null) setSheetState(() => pickedFile = result.files.first);
                },
                icon: const Icon(IconlyLight.upload),
                label: Text(pickedFile?.name ?? "إرفاق ملف الواجب"),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isEmpty) return;
                  Navigator.pop(context);
                  final error = await _assignmentsService.createAssignment(
                    sessionId: widget.sessionId,
                    title: titleController.text,
                    description: descController.text,
                    pickerFile: pickedFile,
                    dueDate: selectedDate,
                  );
                  if (error == null) _loadAssignments();
                },
                child: const Text("نشر الواجب الآن"),
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
      appBar: AppBar(title: Text("واجبات ${widget.subjectName}")),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _assignments.length,
                itemBuilder: (context, index) {
                  final assignment = _assignments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(IconlyBold.document, color: Colors.white)),
                      title: Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("اضغط لرؤية تسليمات الطلاب"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // 🚀 الانتقال لشاشة التسليمات
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TeacherSubmissionsScreen(
                              assignmentId: assignment.id,
                              assignmentTitle: assignment.title,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAssignmentSheet,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Text("لا توجد واجبات مرفوعة"));
  }
}
