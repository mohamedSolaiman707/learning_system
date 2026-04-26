import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/assignment_model.dart';
import '../../../../core/services/assignments_service.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  final String sessionId;
  final String subjectName;

  const StudentAssignmentsScreen({
    super.key,
    required this.sessionId,
    required this.subjectName,
  });

  @override
  State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
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

  Future<void> _handleSubmission(String assignmentId) async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("جاري رفع حلك...")));

    final error = await _assignmentsService.submitAssignment(
      assignmentId: assignmentId,
      pickerFile: result.files.first,
    );

    if (mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تسليم الواجب بنجاح!"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل التسليم: $error"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: Text("واجبات ${widget.subjectName}")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
              ? const Center(child: Text("لا توجد واجبات لهذه المادة حالياً"))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = _assignments[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(IconlyBold.document, color: Colors.blue),
                                const SizedBox(width: 12),
                                Expanded(child: Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                              ],
                            ),
                            if (assignment.description != null) ...[
                              const SizedBox(height: 8),
                              Text(assignment.description!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("آخر موعد: ${assignment.dueDate != null ? DateFormat('MM/dd').format(assignment.dueDate!) : 'مفتوح'}", style: const TextStyle(fontSize: 12)),
                                ElevatedButton.icon(
                                  onPressed: () => _handleSubmission(assignment.id),
                                  icon: const Icon(IconlyLight.upload, size: 18),
                                  label: const Text("تسليم الحل"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade50,
                                    foregroundColor: Colors.blue,
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
