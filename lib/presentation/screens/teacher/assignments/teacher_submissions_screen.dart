import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/submission_model.dart';
import '../../../../core/services/assignments_service.dart';
import '../../../../core/utils/responsive.dart';

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
  List<SubmissionModel> _submissions = [];
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم رصد الدرجة بنجاح ✅", style: TextStyle(fontFamily: 'Cairo')), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ: $e", style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _showGradeDialog(SubmissionModel submission) {
    final gradeController = TextEditingController(text: submission.grade);
    final feedbackController = TextEditingController(text: submission.feedback);
    final bool isDesktop = Responsive.isDesktop(context);

    showDialog(
      context: context,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text("رصد الدرجة والتقييم", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: gradeController,
                  style: const TextStyle(fontFamily: 'Cairo'),
                  decoration: InputDecoration(
                    labelText: "الدرجة (مثلاً: 10/10)",
                    hintText: "أدخل الدرجة المستحقة",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.grade_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: feedbackController,
                  style: const TextStyle(fontFamily: 'Cairo'),
                  decoration: InputDecoration(
                    labelText: "ملاحظات للطالب",
                    hintText: "اكتب تقييمك لمستوى الحل...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.comment_bank_outlined),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateGrade(submission.id, gradeController.text, feedbackController.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF102A43),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("حفظ الدرجة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ],
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
        title: Text("تسليمات: ${widget.assignmentTitle}", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(onPressed: _loadSubmissions, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _submissions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.all(isDesktop ? 30 : 20),
                      itemCount: _submissions.length,
                      itemBuilder: (context, index) => _buildSubmissionCard(_submissions[index]),
                    ),
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(SubmissionModel sub) {
    final bool isGraded = sub.grade != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF102A43).withOpacity(0.1),
          child: Text(sub.studentName?[0].toUpperCase() ?? 'S', 
            style: const TextStyle(color: Color(0xFF102A43), fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo')),
        ),
        title: Text(sub.studentName ?? 'طالب', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isGraded ? Colors.green : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isGraded ? "تم التصحيح (${sub.grade})" : "بانتظار التصحيح",
                  style: TextStyle(color: isGraded ? Colors.green : Colors.orange, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.file_open_outlined, color: Colors.blueAccent),
              onPressed: () => launchUrl(Uri.parse(sub.fileUrl), mode: LaunchMode.externalApplication),
              tooltip: "فتح ملف الحل",
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(isGraded ? Icons.edit_note_rounded : Icons.add_task_rounded, 
                color: isGraded ? Colors.grey : Colors.orangeAccent),
              onPressed: () => _showGradeDialog(sub),
              tooltip: isGraded ? "تعديل الدرجة" : "رصد الدرجة",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("لا توجد تسليمات لهذا الواجب حتى الآن", 
            style: TextStyle(color: Colors.grey, fontSize: 16, fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}
