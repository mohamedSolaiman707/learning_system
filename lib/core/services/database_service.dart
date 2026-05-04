import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  // جلب إحصائيات الإدمن
  Future<Map<String, int>> getAdminStats() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final studentRes = await _supabase.from('profiles').select().eq('role', 'student').count(CountOption.exact);
      final teacherRes = await _supabase.from('profiles').select().eq('role', 'teacher').count(CountOption.exact);
      final roomRes = await _supabase.from('rooms').select().eq('is_active', true).count(CountOption.exact);
      final sessionRes = await _supabase.from('sessions').select().gte('start_time', '${today}T00:00:00').count(CountOption.exact);

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

  // جلب جدول حصص الطالب
  Future<List<Map<String, dynamic>>> getStudentSchedule(String studentId) async {
    try {
      final response = await _supabase
          .from('enrollments')
          .select('sessions(*, profiles:teacher_id(full_name), rooms(is_active))')
          .eq('student_id', studentId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  // تسجيل طالب في حصة باستخدام الكود
  Future<void> enrollStudentByCode(String studentId, String classCode) async {
    try {
      // 1. البحث عن الحصة باستخدام الكود
      final session = await _supabase
          .from('sessions')
          .select('id')
          .eq('class_code', classCode.trim().toUpperCase())
          .maybeSingle();

      if (session == null) {
        throw Exception("كود الحصة غير صحيح");
      }

      // 2. التحقق مما إذا كان الطالب مسجلاً بالفعل
      final existing = await _supabase
          .from('enrollments')
          .select()
          .eq('student_id', studentId)
          .eq('session_id', session['id'])
          .maybeSingle();

      if (existing != null) {
        throw Exception("أنت مسجل بالفعل في هذه الحصة");
      }

      // 3. إضافة الطالب للجدول
      await _supabase.from('enrollments').insert({
        'student_id': studentId,
        'session_id': session['id'],
      });
    } catch (e) {
      rethrow;
    }
  }

  // جلب حصص المدرس لليوم
  Future<List<Map<String, dynamic>>> getTeacherSessions(String teacherId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _supabase
          .from('sessions')
          .select('*, rooms(is_active)')
          .eq('teacher_id', teacherId)
          .gte('start_time', '${today}T00:00:00')
          .order('start_time', ascending: true);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  // تفعيل أو إغلاق الغرفة
  Future<void> toggleRoomStatus(String sessionId, bool isActive) async {
    try {
      await _supabase.from('rooms').upsert({
        'session_id': sessionId,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'session_id');
    } catch (e) {
      rethrow;
    }
  }

  // إدارة المستخدمين
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, role, phone_number, created_at')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _supabase.from('profiles').update({'role': role}).eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _supabase.from('profiles').delete().eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }

  // --- نظام التحضير (Attendance) ---

  Future<List<Map<String, dynamic>>> getEnrolledStudents(String sessionId) async {
    try {
      final response = await _supabase
          .from('enrollments')
          .select('student_id, profiles:student_id(full_name)')
          .eq('session_id', sessionId);
      
      return (response as List).map((e) => {
        'id': e['student_id'],
        'name': e['profiles']['full_name'],
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markAttendance(String sessionId, List<Map<String, dynamic>> attendanceData) async {
    try {
      await _supabase.from('attendance').upsert(attendanceData);
    } catch (e) {
      rethrow;
    }
  }

  // إدارة الحصص (للإدمن)
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

  Future<void> saveSession(Map<String, dynamic> data, {String? id}) async {
    try {
      if (id == null) {
        await _supabase.from('sessions').insert(data);
      } else {
        await _supabase.from('sessions').update(data).eq('id', id);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      await _supabase.from('sessions').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }
}
