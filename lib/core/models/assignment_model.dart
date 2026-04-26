class AssignmentModel {
  final String id;
  final String sessionId;
  final String title;
  final String? description;
  final String? fileUrl;
  final DateTime? dueDate;
  final DateTime createdAt;

  AssignmentModel({
    required this.id,
    required this.sessionId,
    required this.title,
    this.description,
    this.fileUrl,
    this.dueDate,
    required this.createdAt,
  });

  factory AssignmentModel.fromMap(Map<String, dynamic> map) {
    return AssignmentModel(
      id: map['id'],
      sessionId: map['session_id'],
      title: map['title'],
      description: map['description'],
      fileUrl: map['file_url'],
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']).toLocal() : null,
      createdAt: DateTime.parse(map['created_at']).toLocal(),
    );
  }
}
