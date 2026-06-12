// import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:provider/provider.dart';
// import '../../../../core/providers/auth_provider.dart';
// import '../../../../core/services/assignments_service.dart';
// import '../../../../core/models/assignment_model.dart';
// import '../../../../core/models/submission_model.dart';
// import '../../../../core/utils/responsive.dart';
//
// class StudentAssignmentsScreen extends StatefulWidget {
//   final String sessionId;
//   final String subjectName;
//
//   const StudentAssignmentsScreen({
//     super.key,
//     required this.sessionId,
//     required this.subjectName,
//   });
//
//   @override
//   State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
// }
//
// class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
//   final _assignmentsService = AssignmentsService();
//   List<AssignmentModel> _assignments = [];
//   Map<String, SubmissionModel?> _submissions = {};
//   bool _isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }
//
//   Future<void> _loadData() async {
//     setState(() => _isLoading = true);
//     final auth = Provider.of<AuthProvider>(context, listen: false);
//
//     // جلب الواجبات
//     final assignments = await _assignmentsService.getAssignments(widget.sessionId);
//
//     // جلب تسليمات الطالب لكل واجب
//     Map<String, SubmissionModel?> submissionsMap = {};
//     for (var assignment in assignments) {
//       final sub = await _assignmentsService.getStudentSubmission(assignment.id, auth.user!.id);
//       submissionsMap[assignment.id] = sub;
//     }
//
//     setState(() {
//       _assignments = assignments;
//       _submissions = submissionsMap;
//       _isLoading = false;
//     });
//   }
//
//   Future<void> _handleFileUpload(String assignmentId) async {
//     final result = await FilePicker.pickFiles();
//     if (result == null) return;
//
//     // إظهار مؤشر تحميل
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => const Center(child: CircularProgressIndicator()),
//     );
//
//     final error = await _assignmentsService.submitAssignment(
//       assignmentId: assignmentId,
//       pickerFile: result.files.first,
//     );
//
//     if (mounted) Navigator.pop(context); // إغلاق مؤشر التحميل
//
//     if (error == null) {
//       _loadData(); // إعادة تحميل البيانات
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("تم تسليم الواجب بنجاح ✅", style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
//         );
//       }
//     } else {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("خطأ أثناء الرفع: $error", style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isDesktop = Responsive.isDesktop(context);
//
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8F9FB),
//       appBar: AppBar(
//         title: Text("واجبات ${widget.subjectName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black, fontFamily: 'Cairo')),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         iconTheme: const IconThemeData(color: Colors.black),
//       ),
//       body: Center(
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 1200),
//           child: _isLoading
//               ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
//               : _assignments.isEmpty
//                   ? _buildEmptyState()
//                   : ListView.builder(
//                       padding: EdgeInsets.all(isDesktop ? 40 : 20),
//                       itemCount: _assignments.length,
//                       itemBuilder: (context, index) => _buildAssignmentCard(_assignments[index]),
//                     ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAssignmentCard(AssignmentModel assignment) {
//     final submission = _submissions[assignment.id];
//     final bool isSubmitted = submission != null;
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(24),
//         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
//       ),
//       child: Column(
//         children: [
//           ListTile(
//             contentPadding: const EdgeInsets.all(20),
//             leading: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: (isSubmitted ? Colors.green : Colors.orange).withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Icon(isSubmitted ? Icons.check_box_rounded : Icons.description_outlined,
//                 color: isSubmitted ? Colors.green : Colors.orange, size: 28),
//             ),
//             title: Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Cairo')),
//             subtitle: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const SizedBox(height: 6),
//                 Text(assignment.description ?? "لا يوجد وصف إضافي لهذا الواجب",
//                   style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontFamily: 'Cairo')),
//                 if (isSubmitted && submission.grade != null) ...[
//                   const SizedBox(height: 12),
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                     decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
//                     child: Text("الدرجة: ${submission.grade}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
//                   ),
//                 ]
//               ],
//             ),
//           ),
//           const Divider(height: 1),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             child: Row(
//               children: [
//                 if (assignment.fileUrl != null)
//                   TextButton.icon(
//                     onPressed: () => launchUrl(Uri.parse(assignment.fileUrl!), mode: LaunchMode.externalApplication),
//                     icon: const Icon(Icons.file_download_outlined, size: 20),
//                     label: const Text("تحميل الملف", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
//                   ),
//                 const Spacer(),
//                 ElevatedButton(
//                   onPressed: () => _handleFileUpload(assignment.id),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: isSubmitted ? Colors.grey.shade100 : Colors.blue,
//                     foregroundColor: isSubmitted ? Colors.grey.shade700 : Colors.white,
//                     elevation: 0,
//                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                   ),
//                   child: Text(isSubmitted ? "تعديل التسليم" : "تسليم الحل الآن",
//                     style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
//                 ),
//               ],
//             ),
//           ),
//           if (isSubmitted && submission.feedback != null)
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.amber.withOpacity(0.08),
//                 borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
//               ),
//               child: Row(
//                 children: [
//                     Icon(Icons.forum_outlined, color: Colors.amber.shade800, size: 18),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text("ملاحظة المعلم:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontFamily: 'Cairo')),
//                         Text(submission.feedback!, style: const TextStyle(fontSize: 13, color: Colors.black87, fontFamily: 'Cairo')),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(30),
//             decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
//             child: Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey.shade300),
//           ),
//           const SizedBox(height: 24),
//           const Text("لا توجد واجبات مطلوبة حالياً", style: TextStyle(color: Colors.grey, fontSize: 18, fontFamily: 'Cairo')),
//           const SizedBox(height: 8),
//           const Text("سوف تظهر الواجبات هنا فور إضافتها من قبل المعلم", style: TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Cairo')),
//         ],
//       ),
//     );
//   }
// }
