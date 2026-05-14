import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  // --- Admin Stats ---
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

  // --- User Management ---
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _supabase.from('profiles').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTeachersOnly() async {
    try {
      final response = await _supabase.from('profiles').select().eq('role', 'teacher').order('full_name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getProfileByExternalId(String externalId) async {
    try {
      return await _supabase.from('profiles').select().eq('external_id', externalId).maybeSingle();
    } catch (e) {
      return null;
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

  // --- Session Management ---
  Future<List<Map<String, dynamic>>> getAllSessions() async {
    try {
      final response = await _supabase.from('sessions').select('*, profiles!teacher_id(full_name)').order('start_time', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getSessionById(String sessionId) async {
    try {
      return await _supabase.from('sessions').select('*, profiles!teacher_id(full_name), rooms(is_active, room_name)').eq('id', sessionId).maybeSingle();
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSessionByLmsId(String lmsId) async {
    try {
      return await _supabase.from('sessions').select('*, profiles!teacher_id(full_name), rooms(is_active, room_name)').eq('lms_id', lmsId).maybeSingle();
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    try {
      // جلب الحصص التي لها غرفة نشطة حالياً
      final response = await _supabase
          .from('sessions')
          .select('*, profiles!teacher_id(full_name), rooms!inner(is_active, room_name)')
          .eq('rooms.is_active', true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching active sessions: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getStudentSchedule(String studentId) async {
    try {
      final response = await _supabase.from('enrollments').select('*, sessions(*, profiles!teacher_id(full_name), rooms(is_active))').eq('student_id', studentId);
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

      final response = await _supabase.from('sessions').select('*, profiles!teacher_id(full_name), rooms(is_active)').eq('teacher_id', teacherId).gte('start_time', startBoundary).lte('start_time', endBoundary).order('start_time', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTeacherStats(String teacherId) async {
    try {
      final response = await _supabase.from('enrollments').select('student_id, sessions!inner(teacher_id)').eq('sessions.teacher_id', teacherId).count(CountOption.exact);
      return {'totalStudents': response.count, 'rating': '5.0'};
    } catch (_) {
      return {'totalStudents': 0, 'rating': '5.0'};
    }
  }

  Future<void> toggleRoomStatus(String sessionId, bool isActive, {String? roomName}) async {
    try {
      final existing = await _supabase.from('rooms').select('id').eq('session_id', sessionId).maybeSingle();

      if (existing == null) {
        await _supabase.from('rooms').insert({'session_id': sessionId, 'room_name': roomName ?? "room_$sessionId", 'is_active': isActive});
      } else {
        await _supabase.from('rooms').update({'is_active': isActive}).eq('id', existing['id']);
      }
      
      await updateSessionStatus(sessionId, isActive ? 'active' : 'ended');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateSessionStatus(String sessionId, String status) async {
    try {
      await _supabase.from('sessions').update({'status': status}).eq('id', sessionId);
    } catch (e) {
      debugPrint("Error updating session status: $e");
    }
  }

  Future<Map<String, dynamic>?> saveSession(Map<String, dynamic> data, {String? id}) async {
    if (id == null) {
      return await _supabase.from('sessions').insert(data).select().single();
    } else {
      return await _supabase.from('sessions').update(data).eq('id', id).select().single();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _supabase.from('sessions').delete().eq('id', sessionId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> enrollStudentByCode(String studentId, String classCode) async {
    try {
      final res = await _supabase.from('sessions').select('id').eq('class_code', classCode.trim().toUpperCase());
      if (res.isEmpty) throw Exception("كود الحصة غير صحيح");
      final sessionId = res[0]['id'];
      await enrollStudentBySessionId(studentId, sessionId);
    } catch (e) {
      rethrow;
    }
  }

  Stream<int> watchWaitingCount(String sessionId) {
    return _supabase.from('session_waiting_participants').stream(primaryKey: ['id']).eq('session_id', sessionId).map((data) => data.length);
  }


  Future<void> leaveWaitingRoom(String sessionId, String studentId) async {
    try {
      await _supabase.from('session_waiting_participants').delete().eq('session_id', sessionId).eq('student_id', studentId);
    } catch (e) {
      debugPrint("Error leaving waiting room: $e");
    }
  }
  Future<void> joinWaitingRoom(String sessionId, String studentId) async {
    try {
      await _supabase.from('session_waiting_participants').upsert({'session_id': sessionId, 'student_id': studentId});
    } catch (e) {
      debugPrint("Error joining waiting room: $e");
    }
  }
  // --- ميزات غرفة الانتظار ---
  Stream<Map<String, dynamic>> watchSessionStatus(String sessionId) {
    return _supabase.from('sessions').stream(primaryKey: ['id']).eq('id', sessionId).map((data) => data.first);
  }

  Future<void> enrollStudentBySessionId(String studentId, String sessionId) async {
    try {
      await _supabase.from('enrollments').upsert({
        'student_id': studentId,
        'session_id': sessionId,
      }, onConflict: 'student_id, session_id');
    } catch (e) {
      debugPrint("Enrollment error: $e");
      rethrow;
    }
  }

  // --- Attendance Features ---
  Future<void> logStudentEntry(String sessionId, String studentId) async {
    try {
      await _supabase.from('attendance').upsert({
        'session_id': sessionId,
        'student_id': studentId,
        'status': 'present',
        'joined_at': DateTime.now().toIso8601String(),
      }, onConflict: 'session_id, student_id');
    } catch (e) {
      debugPrint("Error logging entry: $e");
    }
  }

  Future<void> logStudentExit(String sessionId, String studentId) async {
    try {
      final record = await _supabase.from('attendance')
          .select('joined_at')
          .eq('session_id', sessionId)
          .eq('student_id', studentId)
          .maybeSingle();

      if (record != null && record['joined_at'] != null) {
        final joinTime = DateTime.parse(record['joined_at']);
        final exitTime = DateTime.now();
        final duration = exitTime.difference(joinTime).inMinutes;

        await _supabase.from('attendance').update({
          'left_at': exitTime.toIso8601String(),
          'total_duration_minutes': duration,
        }).eq('session_id', sessionId).eq('student_id', studentId);
      }
    } catch (e) {
      debugPrint("Error logging exit: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getAttendanceReportData(String sessionId) async {
    try {
      return await _supabase
          .from('attendance')
          .select('*, profiles:student_id(full_name, external_id)')
          .eq('session_id', sessionId);
    } catch (e) {
      rethrow;
    }
  }

  // --- Q&A Features ---
  Future<void> submitQuestion(Map<String, dynamic> questionData) async {
    try {
      await _supabase.from('questions').insert(questionData);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> answerQuestion(String questionId, String answer) async {
    try {
      await _supabase.from('questions').update({'answer': answer, 'is_answered': true}).eq('id', questionId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> togglePinQuestion(String questionId, bool isPinned) async {
    try {
      await _supabase.from('questions').update({'is_pinned': isPinned}).eq('id', questionId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    try {
      await _supabase.from('questions').delete().eq('id', questionId);
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> watchQuestions(String sessionId) {
    return _supabase.from('questions').stream(primaryKey: ['id']).eq('session_id', sessionId).order('is_pinned', ascending: false).order('created_at', ascending: false);
  }

  // --- Quiz Features ---
  Future<Map<String, dynamic>> createQuiz(Map<String, dynamic> quizData) async {
    try {
      return await _supabase.from('quizzes').insert(quizData).select().single();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> submitQuizAnswer(Map<String, dynamic> resultData) async {
    try {
      await _supabase.from('quiz_results').upsert(resultData, onConflict: 'quiz_id, student_id');
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> watchQuizResults(String quizId) {
    return _supabase.from('quiz_results').stream(primaryKey: ['id']).eq('quiz_id', quizId);
  }
}
