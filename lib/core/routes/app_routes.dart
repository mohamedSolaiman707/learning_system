import 'package:flutter/material.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/student/student_main_layout.dart';
import '../../presentation/screens/teacher/teacher_main_layout.dart';
import '../../presentation/screens/admin/admin_dashboard.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String studentHome = '/student-home';
  static const String teacherHome = '/teacher-home';
  static const String adminHome = '/admin-home';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    studentHome: (context) => const StudentMainLayout(),
    teacherHome: (context) => const TeacherMainLayout(),
    adminHome: (context) => const AdminDashboard(),
  };
}
