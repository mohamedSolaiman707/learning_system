import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart'; // إضافة الاستيراد المطلوب

class LiveKitService {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  Future<String?> getRoomToken({
    required String roomName,
    required String userId,
    required String userName,
    String? metadata,
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
          if (metadata != null) 'metadata': metadata,
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

  // المنهج الجديد لجلب توكن الكاميرات الخاصة بالقاعة
  Future<String?> getRoomCameraToken({
    required String roomName,
    required String userId,
    required String cameraName,
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
          'userName': cameraName,
          'isRoomCamera': true, // الحقل الإضافي المطلوب
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

  // المنهج الجديد لنشر بث 3 كاميرات مختلفة
  Future<void> publishRoomCameras(Room room) async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final videoDevices = devices.where((d) => d.kind == 'videoinput').toList();

      final names = ["room-cam-right", "room-cam-left", "room-cam-screen"];

      for (int i = 0; i < videoDevices.length && i < 3; i++) {
        final track = await LocalVideoTrack.createCameraTrack(
          CameraCaptureOptions(deviceId: videoDevices[i].deviceId),
        );

        await room.localParticipant?.publishVideoTrack(
          track,
          publishOptions: VideoPublishOptions(
            name: names[i], // تسمية التراك حسب المطلوب
          ),
        );
      }
    } catch (e) {
      // يمكن إضافة تسجيل للأخطاء هنا
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