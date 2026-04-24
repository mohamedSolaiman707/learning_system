import 'dart:convert';
import 'package:http/http.dart' as http;

class LiveKitService {
  // استخدام String.fromEnvironment بدلاً من dotenv لضمان عملها على الويب
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String liveKitUrl = String.fromEnvironment('LIVEKIT_URL');

  Future<String?> getRoomToken(String roomName, String userName) async {
    try {
      if (supabaseUrl.isEmpty) {
        print('Error: SUPABASE_URL is not set.');
        return null;
      }

      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/get-livekit-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
        },
        body: jsonEncode({
          'roomName': roomName,
          'userName': userName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'];
      } else {
        print('Error getting token: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception getting token: $e');
      return null;
    }
  }
}
