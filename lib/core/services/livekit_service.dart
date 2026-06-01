import 'dart:convert';
import 'package:http/http.dart' as http;

class LiveKitService {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  Future<String?> getRoomToken({
    required String roomName,
    required String userId,
    required String userName,
  }) async {
    try {
      if (supabaseUrl.isEmpty) return null;

      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/get-livekit-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
        },
        body: jsonEncode({
          'roomName': roomName,
          'userId': userId,
          'userName': userName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ميزة جديدة: تسجيل مجموعات العمل في قاعدة البيانات للتقارير
  Future<bool> logBreakoutSession({
    required String parentSessionId,
    required List<Map<String, dynamic>> groups, // قائمة تحتوي على الطلاب في كل مجموعة
    required int durationMinutes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/manage-breakout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
        },
        body: jsonEncode({
          'action': 'start',
          'sessionId': parentSessionId,
          'groups': groups,
          'duration': durationMinutes,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> startRecording(String roomName, String sessionId) async {
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/livekit-recording'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
        },
        body: jsonEncode({
          'action': 'start',
          'roomName': roomName,
          'sessionId': sessionId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> stopRecording(String roomName, String sessionId) async {
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/livekit-recording'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
        },
        body: jsonEncode({
          'action': 'stop',
          'roomName': roomName,
          'sessionId': sessionId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
