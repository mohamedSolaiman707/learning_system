// class QuizModel {
//   final String id;
//   final String sessionId;
//   final String question;
//   final List<String> options;
//   final int correctOptionIndex;
//   final int timeLimitSeconds;
//   final DateTime createdAt;
//
//   QuizModel({
//     required this.id,
//     required this.sessionId,
//     required this.question,
//     required this.options,
//     required this.correctOptionIndex,
//     required this.timeLimitSeconds,
//     required this.createdAt,
//   });
//
//   factory QuizModel.fromMap(Map<String, dynamic> map) {
//     return QuizModel(
//       id: map['id'],
//       sessionId: map['session_id'],
//       question: map['question'],
//       options: List<String>.from(map['options']),
//       correctOptionIndex: map['correct_option_index'],
//       timeLimitSeconds: map['time_limit_seconds'] ?? 60,
//       createdAt: DateTime.parse(map['created_at']).toLocal(),
//     );
//   }
//
//   Map<String, dynamic> toMap() {
//     return {
//       'session_id': sessionId,
//       'question': question,
//       'options': options,
//       'correct_option_index': correctOptionIndex,
//       'time_limit_seconds': timeLimitSeconds,
//     };
//   }
// }
//
// class QuizResultModel {
//   final String studentId;
//   final String studentName;
//   final int selectedIndex;
//   final bool isCorrect;
//
//   QuizResultModel({
//     required this.studentId,
//     required this.studentName,
//     required this.selectedIndex,
//     required this.isCorrect,
//   });
//
//   factory QuizResultModel.fromMap(Map<String, dynamic> map) {
//     return QuizResultModel(
//       studentId: map['student_id'],
//       studentName: map['student_name'] ?? 'طالب',
//       selectedIndex: map['selected_option_index'],
//       isCorrect: map['is_correct'] ?? false,
//     );
//   }
// }
