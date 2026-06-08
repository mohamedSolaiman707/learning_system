import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveKitService {
  // جلب القيم مباشرة من مكتبة Supabase لضمان عدم وجود قيم فارغة
  static String get supabaseUrl => Supabase.instance.client.supabaseUrl;
  static String get supabaseAnonKey => Supabase.instance.client.supabaseAnonKey;

  Future<String?> getRoomToken({
    required String roomName,
    required String userId,
    required String userName,
  }) async {
    try {
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

  Future<bool> pauseRecording(String roomName, String sessionId) async {
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/livekit-recording'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
        },
        body: jsonEncode({
          'action': 'pause',
          'roomName': roomName,
          'sessionId': sessionId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resumeRecording(String roomName, String sessionId) async {
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/livekit-recording'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
        },
        body: jsonEncode({
          'action': 'resume',
          'roomName': roomName,
          'sessionId': sessionId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> logBreakoutSession({
    required String parentSessionId,
    required List<Map<String, dynamic>> groups,
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
}
