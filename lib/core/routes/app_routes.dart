import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/student/student_main_layout.dart';
import '../../presentation/screens/teacher/teacher_main_layout.dart';
import '../../presentation/screens/admin/admin_dashboard.dart';
import '../../presentation/screens/video_room/video_room_screen.dart';
import '../../presentation/screens/video_room/video_room_controller.dart';

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
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == videoRoom) {
      final args = settings.arguments as Map<String, dynamic>?;
      final String roomName = args?['roomName'] ?? '';
      final String userName = args?['userName'] ?? '';
      final String userId = args?['userId'] ?? '';
      final bool isTeacher = args?['isTeacher'] ?? false;
      final String? sessionId = args?['sessionId'];
      final String title = args?['title'] ?? 'غرفة الفيديو';

      return MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => VideoRoomController(
            title: title,
            roomName: roomName,
            userName: userName,
            userId: userId,
            isTeacher: isTeacher,
            sessionId: sessionId,
          ),
          child: VideoRoomScreen(
            title: title,
            roomName: roomName,
            userName: userName,
            userId: userId,
            isTeacher: isTeacher,
            sessionId: sessionId,
          ),
        ),
      );
    }
    return null;
  }
}
