class ResourceModel {
  final String id;
  final String title;
  final String fileUrl;
  final String fileType;
  final DateTime createdAt;

  ResourceModel({
    required this.id,
    required this.title,
    required this.fileUrl,
    required this.fileType,
    required this.createdAt,
  });

  factory ResourceModel.fromMap(Map<String, dynamic> map) {
    return ResourceModel(
      id: map['id'],
      title: map['title'],
      fileUrl: map['file_url'],
      fileType: map['file_type'] ?? 'pdf',
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
