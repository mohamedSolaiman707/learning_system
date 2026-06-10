import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/assignment_model.dart';
import '../../../../core/services/assignments_service.dart';
import '../../../../core/utils/responsive.dart';
import 'teacher_submissions_screen.dart'; 

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
    final bool isDesktop = Responsive.isDesktop(context);

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
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24, right: 24, top: 32,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("إضافة واجب جديد", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  const SizedBox(height: 24),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(fontFamily: 'Cairo'),
                    decoration: InputDecoration(
                      labelText: "عنوان الواجب", 
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    style: const TextStyle(fontFamily: 'Cairo'),
                    decoration: InputDecoration(
                      labelText: "وصف أو تعليمات", 
                      prefixIcon: const Icon(Icons.edit_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.pickFiles(withData: true);
                        if (result != null) setState(() => pickedFile = result.files.first);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(pickedFile?.name ?? "إرفاق ملف الواجب", style: const TextStyle(fontFamily: 'Cairo')),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF102A43),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("نشر الواجب الآن", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text("واجبات ${widget.subjectName}", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(onPressed: _loadAssignments, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _assignments.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.all(isDesktop ? 40 : 20),
                    itemCount: _assignments.length,
                    itemBuilder: (context, index) => _buildAssignmentCard(_assignments[index]),
                  ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAssignmentSheet,
        backgroundColor: const Color(0xFF102A43),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("واجب جديد", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAssignmentCard(AssignmentModel assignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.assignment_outlined, color: Colors.orange, size: 28),
        ),
        title: Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 17)),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              Icon(Icons.people_outline, size: 14, color: Colors.grey),
              SizedBox(width: 6),
              Text("اضغط لمتابعة تسليمات الطلاب", style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        ),
        onTap: () {
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
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          const Text("لا توجد واجبات مرفوعة حالياً", style: TextStyle(color: Colors.grey, fontSize: 18, fontFamily: 'Cairo')),
          const SizedBox(height: 8),
          const Text("يمكنك البدء بإضافة أول واجب من الزر بالأسفل", style: TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}
