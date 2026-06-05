// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../video_room_controller.dart';
//
// class QuizPanel extends StatefulWidget {
//   const QuizPanel({super.key});
//
//   @override
//   State<QuizPanel> createState() => _QuizPanelState();
// }
//
// class _QuizPanelState extends State<QuizPanel> {
//   int? _selectedOption;
//
//   @override
//   Widget build(BuildContext context) {
//     final controller = context.watch<VideoRoomController>();
//     final quiz = controller.activeQuiz;
//
//     // إذا لم يكن هناك اختبار نشط، لا تعرض شيئاً
//     if (quiz == null) return const SizedBox.shrink();
//
//     return Container(
//       margin: const EdgeInsets.all(20),
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(25),
//         boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15)],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // رأس لوحة الاختبار
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text("اختبار سريع 📝",
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                     color: Colors.red.shade50,
//                     borderRadius: BorderRadius.circular(10)
//                 ),
//                 child: Text(
//                     "${controller.quizTimeLeft} ثانية",
//                     style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
//                 ),
//               ),
//             ],
//           ),
//           const Divider(height: 30),
//
//           // نص السؤال
//           Text(
//             quiz.question, // تم التصحيح من title إلى question
//             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 20),
//
//           // خيارات الإجابة
//           ...List.generate(quiz.options.length, (index) { // تم التصحيح للوصول المباشر للخيارات
//             final option = quiz.options[index];
//             return RadioListTile<int>(
//               title: Text(option),
//               value: index,
//               groupValue: _selectedOption,
//               onChanged: controller.quizSubmitted
//                   ? null
//                   : (val) => setState(() => _selectedOption = val),
//               activeColor: Colors.blue,
//             );
//           }),
//
//           const SizedBox(height: 20),
//
//           // زر التسليم أو رسالة النجاح
//           if (!controller.quizSubmitted)
//             SizedBox(
//               width: double.infinity,
//               height: 50,
//               child: ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//                 ),
//                 onPressed: _selectedOption == null ? null : () {
//                   // حساب النتيجة (إذا كانت الإجابة صحيحة يحصل على 10 درجات)
//                   int score = (_selectedOption == quiz.correctOptionIndex) ? 10 : 0;
//                   controller.submitQuiz(score);
//                 },
//                 child: const Text("تسليم الإجابة", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//               ),
//             )
//           else
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.green.shade50,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.check_circle, color: Colors.green),
//                   SizedBox(width: 8),
//                   Text("تم تسليم الإجابة بنجاح",
//                       style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }