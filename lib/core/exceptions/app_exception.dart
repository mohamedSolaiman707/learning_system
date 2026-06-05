// import 'package:supabase_flutter/supabase_flutter.dart';
//
// class AppException implements Exception {
//   final String message;
//   final String? code;
//
//   AppException(this.message, [this.code]);
//
//   @override
//   String toString() => message;
//
//   factory AppException.fromSupabase(dynamic error) {
//     if (error is AuthException) {
//       switch (error.message) {
//         case 'Invalid login credentials':
//           return AppException('البريد الإلكتروني أو كلمة المرور غير صحيحة');
//         case 'Email not confirmed':
//           return AppException('يرجى تأكيد بريدك الإلكتروني أولاً');
//         case 'User already registered':
//           return AppException('هذا البريد الإلكتروني مسجل بالفعل');
//         default:
//           return AppException('حدث خطأ في المصادقة: ${error.message}');
//       }
//     }
//
//     if (error.toString().contains('network_error')) {
//       return AppException('تأكد من اتصالك بالإنترنت');
//     }
//
//     return AppException('عذراً، حدث خطأ غير متوقع. حاول مرة أخرى');
//   }
// }
