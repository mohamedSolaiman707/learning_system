import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/auth/reset_password_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/student/student_main_layout.dart';
import '../../presentation/screens/teacher/teacher_main_layout.dart';
import '../../presentation/screens/admin/admin_dashboard.dart';
import '../../presentation/screens/video_room/video_room_screen.dart';
import '../../presentation/screens/video_room/video_room_controller.dart';
import '../../presentation/screens/video_room/wall_display_screen.dart';
import '../../presentation/screens/video_room/room_publisher_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String resetPassword = '/reset-password';
  static const String studentHome = '/student-home';
  static const String teacherHome = '/teacher-home';
  static const String adminHome = '/admin-home';
  static const String videoRoom = '/video-room';
  static const String wallDisplay = '/wall-display';
  static const String roomPublisher = '/room-publisher';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    resetPassword: (context) => const ResetPasswordScreen(),
    studentHome: (context) => const StudentMainLayout(),
    teacherHome: (context) => const TeacherMainLayout(),
    adminHome: (context) => const AdminDashboard(),
    // roomPublisher route handled via onGenerateRoute
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    String? routeName = settings.name;
    Map<String, dynamic> queryParams = {};

    if (routeName != null && routeName.contains('?')) {
      final uri = Uri.parse(routeName);
      routeName = uri.path;
      queryParams = uri.queryParameters;
    }

    if (routeName == videoRoom) {
      final args = settings.arguments as Map<String, dynamic>? ?? queryParams;
      final String roomName = args['roomName'] ?? '';
      final String userName = args['userName'] ?? 'مستخدم';
      final String userId = args['userId'] ?? '';
      final bool isTeacher = args['isTeacher'] == true || args['isTeacher'] == 'true';
      final String? sessionId = args['sessionId'];
      final String title = args['title'] ?? 'قاعة تعليمية';

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

    if (routeName == wallDisplay) {
      final args = settings.arguments as Map<String, dynamic>? ?? queryParams;
      final String sessionId = args['sessionId'] ?? '';
      final String zone = args['zone'] ?? '';
      final String roomName = args['roomName'] ?? '';
      return MaterialPageRoute(
        builder: (context) => WallDisplayScreen(
          sessionId: sessionId,
          zone: zone,
          roomName: roomName,
        ),
      );
    }

    if (routeName == roomPublisher) {
      final args = settings.arguments as Map<String, dynamic>? ?? queryParams;
      final String roomName = args['roomName'] ?? '';
      final String sessionId = args['sessionId'] ?? '';
      return MaterialPageRoute(
        builder: (context) => RoomPublisherScreen(
          roomName: roomName,
          sessionId: sessionId,
        ),
      );
    }

    return null;
  }
}
