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
    // التأكد من تحويل الوقت القادم من UTC إلى وقت الجهاز المحلي (toLocal)
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
      startTime: startTime,
      endTime: endTime,
      isLive: false,
    );
  }

  // دالة ذكية للتحقق هل الحصة انتهت فعلياً أم لا
  bool get hasEnded => DateTime.now().isAfter(endTime);
}
