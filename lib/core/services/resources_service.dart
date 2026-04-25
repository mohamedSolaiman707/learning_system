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
      final fileExt = pickerFile.extension ?? 'pdf';
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.${fileExt}";
      // مسار الملف: معرف المدرس / اسم الملف
      final filePath = '$userId/$fileName';

      // تحديد الـ Content Type الصحيح لضمان فتح الملف في المتصفح
      String contentType = 'application/octet-stream';
      if (fileExt.toLowerCase() == 'pdf') contentType = 'application/pdf';
      if (['jpg', 'jpeg', 'png'].contains(fileExt.toLowerCase())) contentType = 'image/$fileExt';

      debugPrint("Attempting to upload to path: $filePath with type: $contentType");

      if (kIsWeb) {
        if (pickerFile.bytes == null) throw "File bytes are null";
        await supabase.storage.from('resources').uploadBinary(
          filePath,
          pickerFile.bytes!,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
      } else {
        if (pickerFile.path == null) throw "File path is null";
        await supabase.storage.from('resources').upload(
          filePath,
          File(pickerFile.path!),
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
      }

      final String fileUrl = supabase.storage.from('resources').getPublicUrl(filePath);

      // الخطوة الحاسمة: تسجيل الملف في قاعدة البيانات
      await supabase.from('resources').insert({
        'session_id': sessionId,
        'title': title,
        'file_url': fileUrl,
        'file_type': fileExt,
        'uploaded_by': userId,
      });

      debugPrint("Upload process completed successfully!");
      return true;
    } catch (e) {
      // طباعة الخطأ الحقيقي في الـ Console لمعرفته
      debugPrint("UPLOAD ERROR DETAILS: $e");
      return false;
    }
  }
}
