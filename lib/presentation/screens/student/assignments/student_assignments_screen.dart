import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/assignment_model.dart';
import '../../../../core/models/submission_model.dart';
import '../../../../core/services/assignments_service.dart';
import '../../../../core/providers/auth_provider.dart';

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
  Map<String, SubmissionModel?> _submissions = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = Provider.of<AuthProvider>(context, listen: false).user!.id;
    
    final assignmentsData = await _assignmentsService.getAssignments(widget.sessionId);
    
    Map<String, SubmissionModel?> submissionsData = {};
    for (var assignment in assignmentsData) {
      final sub = await _assignmentsService.getStudentSubmission(assignment.id, userId);
      submissionsData[assignment.id] = sub;
    }

    if (mounted) {
      setState(() {
        _assignments = assignmentsData;
        _submissions = submissionsData;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadAssignment(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تعذر فتح ملف الواجب")),
        );
      }
    }
  }

  Future<void> _handleSubmission(String assignmentId) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
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
        _loadData(); // إعادة التحميل لتحديث الحالة
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
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = _assignments[index];
                    final submission = _submissions[assignment.id];
                    final isSubmitted = submission != null;

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
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(IconlyBold.document, color: Colors.blue),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(
                                        "آخر موعد: ${assignment.dueDate != null ? DateFormat('dd/MM/yyyy').format(assignment.dueDate!) : 'مفتوح'}",
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSubmitted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text("تم التسليم", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            if (assignment.description != null && assignment.description!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(assignment.description!, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                            ],
                            if (isSubmitted && (submission.grade != null || submission.feedback != null)) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (submission.grade != null)
                                      Text("الدرجة: ${submission.grade}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                                    if (submission.feedback != null)
                                      Text("ملاحظة المدرس: ${submission.feedback}", style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                            const Divider(height: 32),
                            Row(
                              children: [
                                if (assignment.fileUrl != null)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _downloadAssignment(assignment.fileUrl),
                                      icon: const Icon(IconlyLight.download, size: 18),
                                      label: const Text("عرض الواجب"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        side: const BorderSide(color: Colors.blue),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                if (assignment.fileUrl != null) const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _handleSubmission(assignment.id),
                                    icon: Icon(isSubmitted ? IconlyLight.edit : IconlyLight.upload, size: 18),
                                    label: Text(isSubmitted ? "تعديل الحل" : "تسليم الحل"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSubmitted ? Colors.grey.shade100 : Colors.blue,
                                      foregroundColor: isSubmitted ? Colors.black87 : Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(IconlyLight.document, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("لا توجد واجبات لهذه المادة حالياً", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
