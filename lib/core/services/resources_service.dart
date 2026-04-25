import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/resource_model.dart';
import 'package:flutter/foundation.dart';

class ResourcesService {
  final supabase = Supabase.instance.client;

  Future<List<ResourceModel>> getResources(String sessionId) async {
    try {
      final response = await supabase
          .from('resources')
          .select()
          .eq('session_id', sessionId);
      
      return (response as List).map((data) => ResourceModel.fromMap(data)).toList();
    } catch (e) {
      debugPrint("Error fetching resources: $e");
      return [];
    }
  }

  Future<bool> uploadResource({
    required String sessionId,
    required String title,
    required PlatformFile pickerFile,
  }) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      // توليد اسم فريد للملف لتجنب التضارب
      final fileExt = pickerFile.extension ?? 'pdf';
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.${fileExt}";
      final filePath = '$userId/$fileName'; // تنظيم الملفات داخل مجلدات باسم المدرس

      debugPrint("Starting upload for: $filePath");

      if (kIsWeb) {
        if (pickerFile.bytes == null) {
          debugPrint("Error: File bytes are null on web");
          return false;
        }
        await supabase.storage.from('resources').uploadBinary(
          filePath,
          pickerFile.bytes!,
          fileOptions: FileOptions(contentType: 'application/$fileExt', upsert: true),
        );
      } else {
        await supabase.storage.from('resources').upload(
          filePath,
          File(pickerFile.path!),
          fileOptions: FileOptions(contentType: 'application/$fileExt', upsert: true),
        );
      }

      // الحصول على الرابط
      final String fileUrl = supabase.storage.from('resources').getPublicUrl(filePath);
      debugPrint("File uploaded successfully. URL: $fileUrl");

      // ربط الملف بالحصّة في جدول الداتابيز
      await supabase.from('resources').insert({
        'session_id': sessionId,
        'title': title,
        'file_url': fileUrl,
        'file_type': fileExt,
        'uploaded_by': userId,
      });

      return true;
    } catch (e) {
      debugPrint("CRITICAL UPLOAD ERROR: $e");
      return false;
    }
  }
}
