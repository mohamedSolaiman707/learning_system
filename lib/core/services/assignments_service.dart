import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assignment_model.dart';
import '../models/submission_model.dart';
import 'package:flutter/foundation.dart';

class AssignmentsService {
  final supabase = Supabase.instance.client;

  // 1. جلب الواجبات كـ AssignmentModel
  Future<List<AssignmentModel>> getAssignments(String sessionId) async {
    try {
      final response = await supabase
          .from('assignments')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: false);
      
      return (response as List).map((data) => AssignmentModel.fromMap(data)).toList();
    } catch (e) {
      debugPrint("Error fetching assignments: $e");
      return [];
    }
  }

  // 2. جلب التسليمات كـ SubmissionModel (هنا الربط الحقيقي)
  Future<List<SubmissionModel>> getSubmissions(String assignmentId) async {
    try {
      final response = await supabase
          .from('submissions')
          .select('*, profiles:student_id(full_name)')
          .eq('assignment_id', assignmentId);
      
      return (response as List).map((data) => SubmissionModel.fromMap(data)).toList();
    } catch (e) {
      debugPrint("Error fetching submissions: $e");
      return [];
    }
  }

  // 3. رفع واجب جديد (للمدرس)
  Future<String?> createAssignment({
    required String sessionId,
    required String title,
    String? description,
    PlatformFile? pickerFile,
    DateTime? dueDate,
  }) async {
    try {
      String? fileUrl;
      if (pickerFile != null) {
        final fileName = "assignment_${DateTime.now().millisecondsSinceEpoch}.${pickerFile.extension}";
        final filePath = 'assignments/$fileName';

        if (kIsWeb) {
          await supabase.storage.from('resources').uploadBinary(filePath, pickerFile.bytes!);
        } else {
          await supabase.storage.from('resources').upload(filePath, File(pickerFile.path!));
        }
        fileUrl = supabase.storage.from('resources').getPublicUrl(filePath);
      }

      await supabase.from('assignments').insert({
        'session_id': sessionId,
        'title': title,
        'description': description,
        'file_url': fileUrl,
        'due_date': dueDate?.toIso8601String(),
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // 4. رفع تسليم جديد (للطلاب)
  Future<String?> submitAssignment({
    required String assignmentId,
    required PlatformFile pickerFile,
  }) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final fileName = "sub_${assignmentId}_$userId.${pickerFile.extension}";
      final filePath = 'submissions/$fileName';

      if (kIsWeb) {
        await supabase.storage.from('resources').uploadBinary(filePath, pickerFile.bytes!);
      } else {
        await supabase.storage.from('resources').upload(filePath, File(pickerFile.path!));
      }
      final fileUrl = supabase.storage.from('resources').getPublicUrl(filePath);

      await supabase.from('submissions').upsert({
        'assignment_id': assignmentId,
        'student_id': userId,
        'file_url': fileUrl,
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
