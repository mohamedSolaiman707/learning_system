class QuestionModel {
  final String id;
  final String sessionId;
  final String studentId;
  final String studentName;
  final String content;
  final String? answer;
  final bool isAnswered;
  final bool isPinned;
  final DateTime createdAt;

  QuestionModel({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.content,
    this.answer,
    this.isAnswered = false,
    this.isPinned = false,
    required this.createdAt,
  });

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      id: map['id'],
      sessionId: map['session_id'],
      studentId: map['student_id'],
      studentName: map['student_name'] ?? 'طالب',
      content: map['content'],
      answer: map['answer'],
      isAnswered: map['is_answered'] ?? false,
      isPinned: map['is_pinned'] ?? false,
      createdAt: DateTime.parse(map['created_at']).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'student_id': studentId,
      'student_name': studentName,
      'content': content,
      'answer': answer,
      'is_answered': isAnswered,
      'is_pinned': isPinned,
    };
  }
}
