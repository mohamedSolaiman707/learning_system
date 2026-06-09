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

  Future<List<Map<String, dynamic>>> getTeacherSessionsAll(String teacherId) async {
    try {
      final response = await _supabase
          .from('sessions')
          .select('*, profiles!teacher_id(full_name)')
          .eq('teacher_id', teacherId)
          .order('start_time', ascending: false);
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
      final now = DateTime.now().toUtc().toIso8601String();
      final response = await _supabase
          .from('sessions')
          .select('*, profiles!teacher_id(full_name), rooms!inner(is_active, room_name)')
          .eq('rooms.is_active', true)
          .neq('status', 'archived')
          .neq('status', 'ended')
          .gt('end_time', now);
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

      final response = await _supabase.from('sessions')
          .select('*, profiles!teacher_id(full_name), rooms(is_active)')
          .eq('teacher_id', teacherId)
          .neq('status', 'archived')
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
          .eq('sessions.teacher_id', teacherId);

      final uniqueStudents = (response as List).map((e) => e['student_id']).toSet().length;

      return {
        'totalStudents': uniqueStudents,
        'rating': '5.0',
        'todaySessionsCount': await _getTodaySessionsCount(teacherId)
      };
    } catch (e) {
      debugPrint("Error getting teacher stats: $e");
      return {'totalStudents': 0, 'rating': '5.0', 'todaySessionsCount': 0};
    }
  }

  Future<Map<String, dynamic>> getStudentStats(String studentId) async {
    try {
      final attendanceRes = await _supabase
          .from('attendance')
          .select('total_duration_minutes')
          .eq('student_id', studentId);
      
      double totalMinutes = 0;
      int completedSessions = 0;
      if (attendanceRes != null) {
        for (var row in (attendanceRes as List)) {
          totalMinutes += (row['total_duration_minutes'] ?? 0);
          completedSessions++;
        }
      }

      final quizRes = await _supabase
          .from('quiz_results')
          .select('is_correct')
          .eq('student_id', studentId);
      
      int quizPoints = 0;
      if (quizRes != null) {
        for (var row in (quizRes as List)) {
          if (row['is_correct'] == true) {
            quizPoints += 10;
          }
        }
      }

      int hours = (totalMinutes / 60).floor();
      int mins = (totalMinutes % 60).round();

      String formattedHours = hours > 0 
          ? "$hours س ${mins > 0 ? 'و $mins د' : ''}" 
          : "$mins دقيقة";

      return {
        'learningHours': formattedHours,
        'points': (completedSessions * 10) + quizPoints,
        'completedSessions': completedSessions,
      };
    } catch (e) {
      debugPrint("Error getting student stats: $e");
      return {'learningHours': "0", 'points': 0, 'completedSessions': 0};
    }
  }

  Future<int> _getTodaySessionsCount(String teacherId) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();

    final res = await _supabase.from('sessions')
        .select()
        .eq('teacher_id', teacherId)
        .gte('start_time', startOfToday)
        .lte('start_time', endOfToday)
        .count(CountOption.exact);
    return res.count;
  }

  // --- Recordings Management ---
  Future<List<Map<String, dynamic>>> getSessionRecordings(String sessionId) async {
    try {
      final response = await _supabase
          .from('recordings')
          .select('*')
          .eq('session_id', sessionId)
          .eq('status', 'completed')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching recordings: $e");
      return [];
    }
  }

  Future<void> addRecordingRecord(Map<String, dynamic> data) async {
    try {
      await _supabase.from('recordings').insert(data);
    } catch (e) {
      debugPrint("Error adding recording: $e");
    }
  }

  // --- Attendance, Q&A, and others ---

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

  Stream<List<Map<String, dynamic>>> watchSessionStatus(String sessionId) {
    return _supabase.from('sessions').stream(primaryKey: ['id']).eq('id', sessionId);
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

  Future<bool> isStudentKicked(String sessionId, String studentId) async {
    try {
      final res = await _supabase
          .from('attendance')
          .select('status')
          .eq('session_id', sessionId)
          .eq('student_id', studentId)
          .limit(1);

      if (res.isEmpty) return false;
      return res[0]['status'] == 'kicked';
    } catch (e) {
      return false;
    }
  }

  Future<void> markStudentAsKicked(String sessionId, String studentId) async {
    try {
      await _supabase.from('attendance').upsert({
        'session_id': sessionId,
        'student_id': studentId,
        'status': 'absent',
        'left_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'session_id, student_id');
    } catch (e) {
      debugPrint("Error marking student as kicked: $e");
    }
  }

  Future<void> logStudentEntry(String sessionId, String studentId, String studentName) async {
    try {
      debugPrint("Attempting to log entry: Session($sessionId) Student($studentId)");
      final isKicked = await isStudentKicked(sessionId, studentId);
      if (isKicked) return;

      final profile = await _supabase.from('profiles').select('id').eq('id', studentId).maybeSingle();
      if (profile == null) {
        await _supabase.from('profiles').insert({'id': studentId, 'full_name': studentName, 'role': 'student'});
      }

      final existingEnroll = await _supabase.from('enrollments')
          .select('id').eq('session_id', sessionId).eq('student_id', studentId).maybeSingle();

      if (existingEnroll == null) {
        await _supabase.from('enrollments').insert({'session_id': sessionId, 'student_id': studentId});
      }

      final existingAtt = await _supabase.from('attendance')
          .select('id, total_duration_minutes')
          .eq('session_id', sessionId).eq('student_id', studentId).maybeSingle();

      if (existingAtt == null) {
        await _supabase.from('attendance').insert({
          'session_id': sessionId,
          'student_id': studentId,
          'status': 'present',
          'joined_at': DateTime.now().toUtc().toIso8601String(),
          'total_duration_minutes': 0,
        });
      } else {
        await _supabase.from('attendance').update({
          'status': 'present',
          'joined_at': DateTime.now().toUtc().toIso8601String(),
          'left_at': null,
        }).eq('id', existingAtt['id']);
      }
    } catch (e) {
      debugPrint("❌ CRITICAL ERROR in logStudentEntry: $e");
    }
  }

  Future<void> logStudentExit(String sessionId, String studentId) async {
    try {
      final record = await _supabase.from('attendance')
          .select('id, status, joined_at, left_at, total_duration_minutes')
          .eq('session_id', sessionId)
          .eq('student_id', studentId)
          .maybeSingle();

      if (record != null) {
        if (record['status'] == 'kicked') return;
        if (record['left_at'] != null) return; 

        final joinTime = record['joined_at'] != null ? DateTime.parse(record['joined_at']) : DateTime.now().toUtc();
        final exitTime = DateTime.now().toUtc();
        final sessionDuration = exitTime.difference(joinTime).inMinutes;
        final totalDuration = (record['total_duration_minutes'] ?? 0) + sessionDuration;

        await _supabase.from('attendance').update({
          'left_at': exitTime.toUtc().toIso8601String(),
          'total_duration_minutes': totalDuration,
          'status': 'present'
        }).eq('id', record['id']);
      }
    } catch (e) {
      debugPrint("Error logging exit: $e");
    }
  }

  Future<void> finalizeSessionAttendance(String sessionId) async {
    try {
      final now = DateTime.now().toUtc();
      final activeRecords = await _supabase.from('attendance')
          .select('id, student_id, joined_at, total_duration_minutes')
          .eq('session_id', sessionId)
          .filter('left_at', 'is', null);

      for (var record in activeRecords) {
        final joinTimeStr = record['joined_at'];
        if (joinTimeStr != null) {
          final joinTime = DateTime.parse(joinTimeStr);
          final sessionDuration = now.difference(joinTime).inMinutes;
          final totalDuration = (record['total_duration_minutes'] ?? 0) + sessionDuration;

          await _supabase.from('attendance').update({
            'left_at': now.toUtc().toIso8601String(),
            'total_duration_minutes': totalDuration,
            'status': 'present'
          }).eq('id', record['id']);
        }
      }
    } catch (e) {
      debugPrint("Error finalizing attendance: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getSessionAttendance(String sessionId) async {
    try {
      final attendanceResponse = await _supabase
          .from('attendance')
          .select('*, profiles:student_id(full_name)')
          .eq('session_id', sessionId);

      final List<Map<String, dynamic>> attendanceData = List<Map<String, dynamic>>.from(attendanceResponse);

      final enrollmentsResponse = await _supabase
          .from('enrollments')
          .select('student_id, profiles:student_id(full_name)')
          .eq('session_id', sessionId);

      final List<Map<String, dynamic>> enrollmentsData = List<Map<String, dynamic>>.from(enrollmentsResponse);

      final List<Map<String, dynamic>> report = [];
      final Set<String> processedIds = {};

      for (var record in attendanceData) {
        final studentId = record['student_id'];
        processedIds.add(studentId);
        report.add({
          'name': record['profiles'] != null ? record['profiles']['full_name'] : 'طالب غير مسجل',
          'present': record['status'] != 'absent',
          'joined_at': _formatTime(record['joined_at']),
          'left_at': _formatTime(record['left_at']),
          'duration': record['total_duration_minutes'] ?? 0,
        });
      }

      for (var enrollment in enrollmentsData) {
        final studentId = enrollment['student_id'];
        if (!processedIds.contains(studentId)) {
          report.add({
            'name': enrollment['profiles'] != null ? enrollment['profiles']['full_name'] : 'طالب غائب',
            'present': false,
            'joined_at': 'لم يحضر',
            'left_at': '---',
            'duration': 0,
          });
        }
      }
      return report;
    } catch (e) {
      debugPrint("Error generating attendance report: $e");
      return [];
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr == '---') return '---';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      // تحويل الوقت لنظام 12 ساعة مع ص/م
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'م' : 'ص';
      return "${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period";
    } catch (_) { return dateStr; }
  }

  Future<List<Map<String, dynamic>>> getSessionEnrollments(String sessionId) async {
    try {
      return await _supabase
          .from('enrollments')
          .select('student_id, profiles:student_id(full_name)')
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

  Future<List<Map<String, dynamic>>> getSessionQuizResults(String sessionId) async {
    try {
      return await _supabase
          .from('quiz_results')
          .select('*, quizzes!inner(session_id)')
          .eq('quizzes.session_id', sessionId);
    } catch (e) {
      return [];
    }
  }
}
