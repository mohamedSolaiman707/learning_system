import 'package:flutter/material.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/student/student_main_layout.dart';
import '../../presentation/screens/teacher/teacher_main_layout.dart';
import '../../presentation/screens/admin/admin_dashboard.dart';
import '../../presentation/screens/video_room/video_room_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String studentHome = '/student-home';
  static const String teacherHome = '/teacher-home';
  static const String adminHome = '/admin-home';
  static const String videoRoom = '/video-room'; // إضافة مسار الغرفة

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    studentHome: (context) => const StudentMainLayout(),
    teacherHome: (context) => const TeacherMainLayout(),
    adminHome: (context) => const AdminDashboard(),
    // ملاحظة: VideoRoom تحتاج لبارامترات، سنعالجها عبر onGenerateRoute أو تمرير Arguments
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == videoRoom) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (context) => VideoRoomScreen(
          roomName: args?['roomName'] ?? '',
          userName: args?['userName'] ?? '', // تأكد من الاسم
          userId: args?['userId'] ?? '',     // تمرير الـ ID
          isTeacher: args?['isTeacher'] ?? false,
          sessionId: args?['sessionId'] ?? '',
          title: args?['title'] ?? '',
        ),
      );
    }
    return null;
  }
}
