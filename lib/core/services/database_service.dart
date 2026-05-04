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

  // جلب كل المستخدمين
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

  // تحديث رتبة المستخدم
  Future<void> updateUserRole(String id, String newRole) async {
    try {
      await _supabase.from('profiles').update({'role': newRole}).eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  // حذف مستخدم
  Future<void> deleteUser(String id) async {
    try {
      await _supabase.from('profiles').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  // --- إدارة الحصص ---

  // جلب كل الحصص (للأدمن)
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

  // جلب المدرسين فقط (للأدمن عند إنشاء حصة)
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

  // حذف حصة
  Future<void> deleteSession(String sessionId) async {
    try {
      await _supabase.from('sessions').delete().eq('id', sessionId);
    } catch (e) {
      rethrow;
    }
  }

  // جلب جدول حصص الطالب
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

  // جلب حصص المدرس
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

  // جلب إحصائيات المدرس الفعلية
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

  // تسجيل طالب بكود الحصة
  Future<void> enrollStudentByCode(String studentId, String classCode) async {
    final session = await _supabase.from('sessions').select('id').eq('class_code', classCode.trim().toUpperCase()).maybeSingle();
    if (session == null) throw Exception("كود الحصة غير صحيح");
    await _supabase.from('enrollments').insert({'student_id': studentId, 'session_id': session['id']});
  }

  // حفظ أو تعديل حصة
  Future<void> saveSession(Map<String, dynamic> data, {String? id}) async {
    if (id == null) {
      await _supabase.from('sessions').insert(data);
    } else {
      await _supabase.from('sessions').update(data).eq('id', id);
    }
  }
}
