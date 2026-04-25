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

  // الآن تعيد String? (null يعني نجاح، والنص هو رسالة الخطأ)
  Future<String?> uploadResource({
    required String sessionId,
    required String title,
    required PlatformFile pickerFile,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return "يجب تسجيل الدخول أولاً";

      final fileExt = pickerFile.extension ?? 'pdf';
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.$fileExt";
      final filePath = '$userId/$fileName';

      String contentType = 'application/octet-stream';
      if (fileExt.toLowerCase() == 'pdf') contentType = 'application/pdf';
      if (['jpg', 'jpeg', 'png'].contains(fileExt.toLowerCase())) contentType = 'image/$fileExt';

      // 1. محاولة الرفع للتخزين
      if (kIsWeb) {
        if (pickerFile.bytes == null) return "لم يتم العثور على بيانات الملف";
        await supabase.storage.from('resources').uploadBinary(
          filePath,
          pickerFile.bytes!,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
      } else {
        if (pickerFile.path == null) return "مسار الملف غير صحيح";
        await supabase.storage.from('resources').upload(
          filePath,
          File(pickerFile.path!),
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
      }

      final String fileUrl = supabase.storage.from('resources').getPublicUrl(filePath);

      // 2. محاولة التسجيل في جدول البيانات
      await supabase.from('resources').insert({
        'session_id': sessionId,
        'title': title,
        'file_url': fileUrl,
        'file_type': fileExt,
        'uploaded_by': userId,
      });

      return null; // نجاح
    } on StorageException catch (e) {
      return "خطأ في التخزين: ${e.message}";
    } on PostgrestException catch (e) {
      return "خطأ في قاعدة البيانات: ${e.message}";
    } catch (e) {
      return "خطأ غير متوقع: $e";
    }
  }
}
