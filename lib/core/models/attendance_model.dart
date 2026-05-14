class AttendanceRecordModel {
  final String studentId;
  final String studentName;
  final String? studentExternalId;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final int totalDurationMinutes;
  final String status;

  AttendanceRecordModel({
    required this.studentId,
    required this.studentName,
    this.studentExternalId,
    this.joinedAt,
    this.leftAt,
    this.totalDurationMinutes = 0,
    this.status = 'absent',
  });

  factory AttendanceRecordModel.fromMap(Map<String, dynamic> map) {
    return AttendanceRecordModel(
      studentId: map['student_id'],
      studentName: map['profiles']?['full_name'] ?? 'طالب غير معروف',
      studentExternalId: map['profiles']?['external_id'],
      joinedAt: map['joined_at'] != null ? DateTime.parse(map['joined_at']).toLocal() : null,
      leftAt: map['left_at'] != null ? DateTime.parse(map['left_at']).toLocal() : null,
      totalDurationMinutes: map['total_duration_minutes'] ?? 0,
      status: map['status'] ?? 'absent',
    );
  }
}
