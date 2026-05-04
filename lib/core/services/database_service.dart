import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  // جلب إحصائيات الإدمن
  Future<Map<String, int>> getAdminStats() async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

      final studentRes = await _supabase.from('profiles').select().eq('role', 'student').count(CountOption.exact);
      final teacherRes = await _supabase.from('profiles').select().eq('role', 'teacher').count(CountOption.exact);
      final roomRes = await _supabase.from('rooms').select().eq('is_active', true).count(CountOption.exact);
      final sessionRes = await _supabase.from('sessions').select().gte('start_time', startOfToday).count(CountOption.exact);

      return {
        'totalStudents': studentRes.count,
        'totalTeachers': teacherRes.count,
        'activeRooms': roomRes.count,
        'todaySessions': sessionRes.count,
      };
    } catch (e) {
      rethrow;
    }
  }

  // --- إدارة المستخدمين ---

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserRole(String id, String newRole) async {
    try {
      await _supabase.from('profiles').update({'role': newRole}).eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProfile(String id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('profiles').update(data).eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _supabase.from('profiles').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  // --- إدارة الحصص ---

  Future<List<Map<String, dynamic>>> getAllSessions() async {
    try {
      final response = await _supabase
          .from('sessions')
          .select('*, profiles:teacher_id(full_name)')
          .order('start_time', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTeachersOnly() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'teacher');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _supabase.from('sessions').delete().eq('id', sessionId);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getStudentSchedule(String studentId) async {
    try {
      final response = await _supabase
          .from('enrollments')
          .select('*, sessions(*, profiles:teacher_id(full_name), rooms(is_active))')
          .eq('student_id', studentId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTeacherSessions(String teacherId) async {
    try {
      final now = DateTime.now();
      final startBoundary = DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 12)).toUtc().toIso8601String();
      final endBoundary = DateTime(now.year, now.month, now.day).add(const Duration(hours: 36)).toUtc().toIso8601String();

      final response = await _supabase
          .from('sessions')
          .select('*, profiles:teacher_id(full_name), rooms(is_active)')
          .eq('teacher_id', teacherId)
          .gte('start_time', startBoundary)
          .lte('start_time', endBoundary)
          .order('start_time', ascending: true);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTeacherStats(String teacherId) async {
    try {
      final response = await _supabase
          .from('enrollments')
          .select('student_id, sessions!inner(teacher_id)')
          .eq('sessions.teacher_id', teacherId)
          .count(CountOption.exact);
          
      return {
        'totalStudents': response.count,
        'rating': '5.0',
      };
    } catch (_) {
      return {'totalStudents': 0, 'rating': '5.0'};
    }
  }

  // تفعيل أو إغلاق الغرفة (تم التحويل لـ upsert حقيقي لضمان التحديث)
  Future<void> toggleRoomStatus(String sessionId, bool isActive, {String? roomName}) async {
    try {
      await _supabase.from('rooms').upsert({
        'session_id': sessionId,
        'room_name': roomName ?? "room_$sessionId",
        'is_active': isActive,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'session_id');
      
      print("Room status updated: $sessionId -> $isActive");
    } catch (e) {
      print("ToggleRoom Error: $e");
      rethrow;
    }
  }

  // تسجيل طالب بكود الحصة
  Future<void> enrollStudentByCode(String studentId, String classCode) async {
    try {
      final cleanCode = classCode.trim().toUpperCase();

      final response = await _supabase.from('sessions')
          .select('id')
          .eq('class_code', cleanCode);
          
      if (response.isEmpty) throw Exception("كود الحصة غير صحيح أو غير موجود");

      final sessionId = response[0]['id'];

      final existing = await _supabase.from('enrollments')
          .select()
          .eq('student_id', studentId)
          .eq('session_id', sessionId)
          .maybeSingle();

      if (existing != null) throw Exception("أنت مسجل بالفعل في هذه الحصة");

      await _supabase.from('enrollments').insert({
        'student_id': studentId,
        'session_id': sessionId
      });
    } catch (e) {
      print("Enroll Error: $e");
      rethrow;
    }
  }

  Future<void> saveSession(Map<String, dynamic> data, {String? id}) async {
    if (id == null) {
      await _supabase.from('sessions').insert(data);
    } else {
      await _supabase.from('sessions').update(data).eq('id', id);
    }
  }
}
