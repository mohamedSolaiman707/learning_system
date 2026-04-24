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
    final startTime = DateTime.parse(map['start_time']);
    final endTime = DateTime.parse(map['end_time']);
    final now = DateTime.now();
    
    // الحصة تكون مباشرة إذا كان الوقت الحالي بين وقت البدء والانتهاء
    final isLive = now.isAfter(startTime) && now.isBefore(endTime);

    return SessionModel(
      id: map['id'],
      subjectName: map['subject_name'],
      teacherName: map['profiles']['full_name'], // جلب اسم المدرس من العلاقة
      startTime: startTime,
      endTime: endTime,
      isLive: isLive,
    );
  }
}
