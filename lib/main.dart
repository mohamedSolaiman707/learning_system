import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Supabase باستخدام المتغيرات التي نمررها أثناء البناء
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduConnect | منصة التعليم الذكي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // التوجيه التلقائي بناءً على حالة الجلسة
      home: const AuthWrapper(),
      routes: AppRoutes.routes,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

/// ويدجت للتحقق من حالة المستخدم عند فتح التطبيق
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // ننتظر قليلاً لمحاكاة الـ Splash أو التأكد من استقرار الجلسة
    await Future.delayed(const Duration(seconds: 2));
    
    final session = Supabase.instance.client.auth.currentSession;
    
    if (!mounted) return;

    if (session == null) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } else {
      // جلب دور المستخدم لتوجيهه للمكان الصحيح
      try {
        final userId = session.user.id;
        final userData = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .single();
        
        final role = userData['role'] as String;
        
        if (!mounted) return;

        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, AppRoutes.adminHome);
        } else if (role == 'teacher') {
          Navigator.pushReplacementNamed(context, AppRoutes.teacherHome);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
        }
      } catch (e) {
        // في حال فشل جلب البيانات، نوجهه لتسجيل الدخول
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_rounded, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
