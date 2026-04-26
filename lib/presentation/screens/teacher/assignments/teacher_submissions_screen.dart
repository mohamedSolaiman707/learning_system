import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/submission_model.dart'; // استخدام الموديل الجديد
import '../../../../core/services/assignments_service.dart';

class TeacherSubmissionsScreen extends StatefulWidget {
  final String assignmentId;
  final String assignmentTitle;

  const TeacherSubmissionsScreen({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  @override
  State<TeacherSubmissionsScreen> createState() => _TeacherSubmissionsScreenState();
}

class _TeacherSubmissionsScreenState extends State<TeacherSubmissionsScreen> {
  final _assignmentsService = AssignmentsService();
  List<SubmissionModel> _submissions = []; // تم تغيير النوع للموديل
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);
    final data = await _assignmentsService.getSubmissions(widget.assignmentId);
    setState(() {
      _submissions = data;
      _isLoading = false;
    });
  }

  Future<void> _updateGrade(String submissionId, String grade, String feedback) async {
    try {
      await _assignmentsService.supabase
          .from('submissions')
          .update({'grade': grade, 'feedback': feedback})
          .eq('id', submissionId);
      
      _loadSubmissions();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم رصد الدرجة بنجاح")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  void _showGradeDialog(SubmissionModel submission) {
    final gradeController = TextEditingController(text: submission.grade);
    final feedbackController = TextEditingController(text: submission.feedback);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("رصد الدرجة والتقييم"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: gradeController,
              decoration: const InputDecoration(labelText: "الدرجة (مثلاً: 10/10)"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(labelText: "ملاحظات للمطالب"),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateGrade(submission.id, gradeController.text, feedbackController.text);
            },
            child: const Text("حفظ الدرجة"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: Text("تسليمات: ${widget.assignmentTitle}")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _submissions.isEmpty
              ? const Center(child: Text("لا توجد تسليمات حتى الآن"))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _submissions.length,
                  itemBuilder: (context, index) {
                    final sub = _submissions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(IconlyLight.user_1)),
                        title: Text(sub.studentName ?? 'طالب'),
                        subtitle: Text(sub.grade != null ? "الدرجة: ${sub.grade}" : "بانتظار التصحيح"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(IconlyLight.show, color: Colors.blue),
                              onPressed: () => launchUrl(Uri.parse(sub.fileUrl)),
                              tooltip: "عرض الحل",
                            ),
                            IconButton(
                              icon: const Icon(IconlyLight.edit, color: Colors.orange),
                              onPressed: () => _showGradeDialog(sub),
                              tooltip: "رصد الدرجة",
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
