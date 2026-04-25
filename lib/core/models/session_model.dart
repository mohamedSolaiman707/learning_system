class SessionModel {
  final String id;
  final String subjectName;
  final String teacherName;
  final DateTime startTime;
  final DateTime endTime;
  final bool isLive;

  SessionModel({
    required this.id,
    required this.subjectName,
    required this.teacherName,
    required this.startTime,
    required this.endTime,
    this.isLive = false,
  });

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    final startTime = DateTime.parse(map['start_time'] ?? DateTime.now().toIso8601String());
    final endTime = DateTime.parse(map['end_time'] ?? DateTime.now().add(const Duration(hours: 1)).toIso8601String());
    
    // جلب اسم المدرس بشكل آمن لتجنب الـ Null Check Error
    String teacherName = "مدرس غير معروف";
    if (map['profiles'] != null) {
      teacherName = map['profiles']['full_name'] ?? "مدرس";
    }

    return SessionModel(
      id: map['id'],
      subjectName: map['subject_name'] ?? 'بدون عنوان',
      teacherName: teacherName,
      startTime: startTime,
      endTime: endTime,
      isLive: false, // يتم تعيينها في الـ Tab بناءً على جدول rooms
    );
  }
}
