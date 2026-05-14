class SessionModel {
  final String id;
  final String subjectName;
  final String teacherName;
  final String classCode;
  final DateTime startTime;
  final DateTime endTime;
  final bool isLive;
  final String status; // 'waiting' | 'active' | 'ended'
  final String? recordingUrl;
  final bool isRecordingEnabled;

  SessionModel({
    required this.id,
    required this.subjectName,
    required this.teacherName,
    required this.classCode,
    required this.startTime,
    required this.endTime,
    this.isLive = false,
    this.status = 'waiting',
    this.recordingUrl,
    this.isRecordingEnabled = true,
  });

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    final startTime = DateTime.parse(map['start_time']).toLocal();
    final endTime = DateTime.parse(map['end_time']).toLocal();
    
    String teacherName = "مدرس";
    if (map['profiles'] != null) {
      teacherName = map['profiles']['full_name'] ?? "مدرس";
    }

    bool liveStatus = false;
    final roomsData = map['rooms'];
    
    if (roomsData != null) {
      if (roomsData is List && roomsData.isNotEmpty) {
        liveStatus = roomsData.any((r) => r['is_active'] == true);
      } else if (roomsData is Map) {
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
      status: map['status'] ?? 'waiting',
      recordingUrl: map['recording_url'],
      isRecordingEnabled: map['is_recording_enabled'] ?? true,
    );
  }

  bool get hasEnded => status == 'ended' || DateTime.now().isAfter(endTime);
  bool get isActive => status == 'active';
  bool get isWaiting => status == 'waiting';
}
