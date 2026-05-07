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
          'userId': userId, // نستخدم الـ UUID كـ Identity
          'userName': userName, // نرسل الاسم كـ Metadata أو ليتم معالجته في الـ Edge Function
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
