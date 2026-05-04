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
    
    String teacherName = "مدرس";
    if (map['profiles'] != null) {
      teacherName = map['profiles']['full_name'] ?? "مدرس";
    }

    // منطق متطور للتحقق من حالة اللايف لضمان الدقة
    bool liveStatus = false;
    final roomsData = map['rooms'];
    
    if (roomsData != null) {
      if (roomsData is List && roomsData.isNotEmpty) {
        // إذا رجعت كقائمة، نتحقق من أي غرفة نشطة
        liveStatus = roomsData.any((r) => r['is_active'] == true);
      } else if (roomsData is Map) {
        // إذا رجعت ككائن واحد
        liveStatus = roomsData['is_active'] == true;
      }
    }

    return SessionModel(
      id: map['id'],
      subjectName: map['subject_name'] ?? 'بدون عنوان',
      teacherName: teacherName,
      classCode: map['class_code'] ?? '',
      startTime: startTime,
      endTime: endTime,
      isLive: liveStatus,
    );
  }

  bool get hasEnded => DateTime.now().isAfter(endTime);
}
