class SubmissionModel {
  final String id;
  final String assignmentId;
  final String studentId;
  final String fileUrl;
  final String? grade;
  final String? feedback;
  final DateTime submittedAt;
  final String? studentName; // حقل إضافي لسهولة العرض في الواجهة

  SubmissionModel({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.fileUrl,
    this.grade,
    this.feedback,
    required this.submittedAt,
    this.studentName,
  });

  factory SubmissionModel.fromMap(Map<String, dynamic> map) {
    return SubmissionModel(
      id: map['id'],
      assignmentId: map['assignment_id'],
      studentId: map['student_id'],
      fileUrl: map['file_url'],
      grade: map['grade'],
      feedback: map['feedback'],
      submittedAt: DateTime.parse(map['submitted_at']).toLocal(),
      studentName: map['profiles']?['full_name'], // قراءة الاسم من الربط (Join)
    );
  }
}
