import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _statsKey = 'cached_student_stats';
  static const String _enrolledSessionsKey = 'cached_enrolled_sessions';
  static const String _activeSessionsKey = 'cached_active_sessions';

  Future<void> saveStudentStats(Map<String, dynamic> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(stats));
  }

  Future<Map<String, dynamic>?> getStudentStats() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_statsKey);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> saveEnrolledSessions(List<Map<String, dynamic>> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_enrolledSessionsKey, jsonEncode(sessions));
  }

  Future<List<Map<String, dynamic>>?> getEnrolledSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_enrolledSessionsKey);
    if (data != null) {
      return (jsonDecode(data) as List).cast<Map<String, dynamic>>();
    }
    return null;
  }

  Future<void> saveActiveSessions(List<Map<String, dynamic>> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeSessionsKey, jsonEncode(sessions));
  }

  Future<List<Map<String, dynamic>>?> getActiveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_activeSessionsKey);
    if (data != null) {
      return (jsonDecode(data) as List).cast<Map<String, dynamic>>();
    }
    return null;
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsKey);
    await prefs.remove(_enrolledSessionsKey);
    await prefs.remove(_activeSessionsKey);
  }
}
