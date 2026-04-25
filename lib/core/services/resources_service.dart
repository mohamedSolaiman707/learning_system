import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/resource_model.dart';
import 'package:flutter/foundation.dart';

class ResourcesService {
  final supabase = Supabase.instance.client;

  // 1. جلب المصادر الخاصة بحصة معينة
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

  // 2. منطق رفع ملف جديد
  Future<bool> uploadResource({
    required String sessionId,
    required String title,
    required PlatformFile pickerFile,
  }) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final fileName = "${DateTime.now().millisecondsSinceEpoch}_${pickerFile.name}";
      final filePath = 'resources/$fileName';

      // رفع الملف إلى Supabase Storage
      if (kIsWeb) {
        await supabase.storage.from('resources').uploadBinary(
          filePath,
          pickerFile.bytes!,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
      } else {
        await supabase.storage.from('resources').upload(
          filePath,
          File(pickerFile.path!),
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
      }

      // الحصول على الرابط العام للملف
      final String fileUrl = supabase.storage.from('resources').getPublicUrl(filePath);

      // تسجيل بيانات الملف في جدول resources
      await supabase.from('resources').insert({
        'session_id': sessionId,
        'title': title,
        'file_url': fileUrl,
        'file_type': pickerFile.extension ?? 'pdf',
        'uploaded_by': userId,
      });

      return true;
    } catch (e) {
      debugPrint("Upload error: $e");
      return false;
    }
  }
}
