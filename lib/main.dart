import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:learning_by_video_call/presentation/screens/admin/admin_dashboard.dart';
import 'package:learning_by_video_call/presentation/screens/auth/login_screen.dart';
import 'package:learning_by_video_call/presentation/screens/student/student_main_layout.dart';
import 'package:learning_by_video_call/presentation/screens/teacher/teacher_main_layout.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/services/database_service.dart';
import 'core/localization/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeDateFormatting('ar_EG', null);
  
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        Provider(create: (_) => DatabaseService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      title: 'EduConnect | منصة التعليم الذكي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const AuthWrapper(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
      routes: AppRoutes.routes,
      locale: localeProvider.locale,
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isRedirecting = false;
  bool _linkProcessed = false;

  @override
  void initState() {
    super.initState();
    _checkLink();
  }

  void _checkLink() {
    // تأخير ثانية واحدة لضمان استقرار الرابط في المتصفح (مهم جداً للويب)
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _handleIncomingLink();
    });
  }

  Future<void> _handleIncomingLink() async {
    if (_linkProcessed) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // إذا لم يكن مسجلاً، ننتظر تسجيل الدخول (سيتم إعادة الفحص تلقائياً من الـ build)
    if (!authProvider.isAuthenticated) return;

    final dbService = Provider.of<DatabaseService>(context, listen: false);

    // 1. استخراج البارامترات بكل الطرق الممكنة (Query + Fragment)
    final fullUri = Uri.base;
    Map<String, String> params = Map.from(fullUri.queryParameters);
    
    // دعم روابط Vercel مثل /#/?session_id=...
    if (fullUri.fragment.contains('?')) {
      final queryPart = fullUri.fragment.split('?').last;
      params.addAll(Uri.splitQueryString(queryPart));
    }

    final sessionId = params['session_id'];
    final lmsId = params['lms_id'];

    if (sessionId != null || lmsId != null) {
      _linkProcessed = true;
      if (mounted) setState(() => _isRedirecting = true);
      
      try {
        debugPrint("Link Detected: session=$sessionId, lms=$lmsId");
        
        final session = sessionId != null 
            ? await dbService.getSessionById(sessionId)
            : await dbService.getSessionByLmsId(lmsId!);

        if (session != null && mounted) {
          String? roomName;
          var roomsData = session['rooms'];
          if (roomsData != null) {
            if (roomsData is List && roomsData.isNotEmpty) {
              roomName = roomsData[0]['room_name'];
            } else if (roomsData is Map) {
              roomName = roomsData['room_name'];
            }
          }

          // التوجيه مع مسح الشاشة السابقة لضمان الدخول المباشر
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.videoRoom,
            (route) => false,
            arguments: {
              'roomName': roomName ?? 'room_${session['id']}',
              'title': session['title'] ?? 'قاعة تعليمية',
              'userName': authProvider.profile?['full_name'] ?? 'Guest',
              'userId': authProvider.user?.id ?? '',
              'isTeacher': authProvider.role == 'teacher',
              'sessionId': session['id'],
            },
          );
        } else {
          // إذا لم يجد الجلسة، نظهر تنبيه بسيط
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('عذراً، لم نتمكن من العثور على هذه الحصة في النظام')),
            );
          }
        }
      } catch (e) {
        debugPrint("Error handling link: $e");
      } finally {
        if (mounted) setState(() => _isRedirecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // إذا تم تسجيل الدخول لاحقاً، نفحص الرابط مجدداً
    if (authProvider.isAuthenticated && !_linkProcessed) {
      _checkLink();
    }

    if (authProvider.isLoading || _isRedirecting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("جاري تحضير القاعة التعليمية...", 
                style: TextStyle(fontFamily: 'Cairo', fontSize: 16)),
            ],
          ),
        ),
      );
    }

    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    final role = authProvider.role;
    if (role == 'admin') return const AdminDashboard();
    if (role == 'teacher') return const TeacherMainLayout();
    return const StudentMainLayout();
  }
}
