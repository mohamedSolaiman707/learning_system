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
  final bool isRecording;
  final bool isRecordingPaused;

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
    this.isRecording = false,
    this.isRecordingPaused = false,
  });

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    // معالجة الأوقات
    final startTime = map['start_time'] != null 
        ? DateTime.parse(map['start_time']).toLocal() 
        : DateTime.now();
    final endTime = map['end_time'] != null 
        ? DateTime.parse(map['end_time']).toLocal() 
        : startTime.add(const Duration(hours: 1));
    
    // استخراج اسم المدرس مع الحماية من القوائم أو الخرائط
    String teacherName = "مدرس غير معروف";
    final profilesData = map['profiles'];
    if (profilesData != null) {
      if (profilesData is Map) {
        teacherName = (profilesData['full_name']?.toString().isNotEmpty == true) 
            ? profilesData['full_name'] 
            : "مدرس";
      } else if (profilesData is List && profilesData.isNotEmpty) {
        teacherName = (profilesData[0]['full_name']?.toString().isNotEmpty == true) 
            ? profilesData[0]['full_name'] 
            : "مدرس";
      }
    }

    // التحقق من حالة البث المباشر (وجود غرفة نشطة)
    bool liveStatus = false;
    final roomsData = map['rooms'];
    if (roomsData != null) {
      if (roomsData is List && roomsData.isNotEmpty) {
        liveStatus = roomsData.any((r) => r['is_active'] == true);
      } else if (roomsData is Map) {
        liveStatus = roomsData['is_active'] == true;
      }
    }

    // استخراج اسم المادة مع قيمة افتراضية إذا كانت فارغة
    String name = map['subject_name']?.toString() ?? "";
    if (name.trim().isEmpty) {
      name = "بث مباشر سريع";
    }

    return SessionModel(
      id: map['id']?.toString() ?? '',
      subjectName: name,
      teacherName: teacherName,
      classCode: map['class_code']?.toString() ?? '',
      startTime: startTime,
      endTime: endTime,
      isLive: liveStatus,
      status: map['status']?.toString() ?? 'waiting',
      recordingUrl: map['recording_url']?.toString(),
      isRecordingEnabled = map['is_recording_enabled'] ?? true,
      isRecording: map['is_recording'] ?? false,
      isRecordingPaused: map['is_recording_paused'] ?? false,
    );
  }

  bool get hasEnded => status == 'ended' || DateTime.now().isAfter(endTime);
  
  // الجلسة تعتبر نشطة إذا كانت حالتها active أو إذا كان البث المباشر قد بدأ بالفعل (isLive)
  bool get isActive => status == 'active' || isLive;
  
  bool get isWaiting => status == 'waiting' && !isLive;
}
