class SessionModel {
  final String id;
  final String subjectName;
  final String teacherName;
  final String classCode;
  final DateTime startTime;
  final DateTime endTime;
  final bool isLive;

  SessionModel({
    required this.id,
    required this.subjectName,
    required this.teacherName,
    required this.classCode,
    required this.startTime,
    required this.endTime,
    this.isLive = false,
  });

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    final startTime = DateTime.parse(map['start_time']).toLocal();
    final endTime = DateTime.parse(map['end_time']).toLocal();
    
    String teacherName = "مدرس غير معروف";
    if (map['profiles'] != null) {
      teacherName = map['profiles']['full_name'] ?? "مدرس";
    }

    return SessionModel(
      id: map['id'],
      subjectName: map['subject_name'] ?? 'بدون عنوان',
      teacherName: teacherName,
      classCode: map['class_code'] ?? '',
      startTime: startTime,
      endTime: endTime,
      isLive: map['rooms'] != null && (map['rooms'] is List && (map['rooms'] as List).isNotEmpty ? map['rooms'][0]['is_active'] : false),
    );
  }

  bool get hasEnded => DateTime.now().isAfter(endTime);
}
