import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/assignments_service.dart';
import '../../../../core/models/assignment_model.dart';
import '../../../../core/models/submission_model.dart';

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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // جلب الواجبات
    final assignments = await _assignmentsService.getAssignments(widget.sessionId);
    
    // جلب تسليمات الطالب لكل واجب
    Map<String, SubmissionModel?> submissionsMap = {};
    for (var assignment in assignments) {
      final sub = await _assignmentsService.getStudentSubmission(assignment.id, auth.user!.id);
      submissionsMap[assignment.id] = sub;
    }

    setState(() {
      _assignments = assignments;
      _submissions = submissionsMap;
      _isLoading = false;
    });
  }

  Future<void> _handleFileUpload(String assignmentId) async {
    final result = await FilePicker.pickFiles();
    if (result == null) return;

    // إظهار مؤشر تحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final error = await _assignmentsService.submitAssignment(
      assignmentId: assignmentId,
      pickerFile: result.files.first,
    );

    if (mounted) Navigator.pop(context); // إغلاق مؤشر التحميل

    if (error == null) {
      _loadData(); // إعادة تحميل البيانات
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم تسليم الواجب بنجاح ✅"), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ أثناء الرفع: $error"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text("واجبات ${widget.subjectName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _assignments.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) => _buildAssignmentCard(_assignments[index]),
                ),
    );
  }

  Widget _buildAssignmentCard(AssignmentModel assignment) {
    final submission = _submissions[assignment.id];
    final bool isSubmitted = submission != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isSubmitted ? Colors.green : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(isSubmitted ? Icons.check_box : Icons.description,
                color: isSubmitted ? Colors.green : Colors.orange, size: 24),
            ),
            title: Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(assignment.description ?? "لا يوجد وصف", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                if (isSubmitted && submission.grade != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text("الدرجة: ${submission.grade}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ]
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (assignment.fileUrl != null)
                  TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse(assignment.fileUrl!)),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text("تحميل الواجب"),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _handleFileUpload(assignment.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSubmitted ? Colors.grey.shade100 : Colors.blue,
                    foregroundColor: isSubmitted ? Colors.grey.shade700 : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isSubmitted ? "تعديل التسليم" : "تسليم الحل"),
                ),
              ],
            ),
          ),
          if (isSubmitted && submission.feedback != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.05), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
              child: Row(
                children: [
                   const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text("ملاحظة المدرس: ${submission.feedback}", style: const TextStyle(fontSize: 12, color: Colors.black87))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("لا توجد واجبات مطلوبة حالياً", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
