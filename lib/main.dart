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
import 'core/services/cache_service.dart';
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
        Provider(create: (_) => CacheService()),
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
  Map<String, String>? _capturedParams;

  @override
  void initState() {
    super.initState();
    _capturedParams = _extractParams();

    final token = _capturedParams!['token'] ?? _capturedParams!['access_token'];
    final sessionId = _capturedParams!['sessionId'] ?? _capturedParams!['session_id'] ?? _capturedParams!['lms_id'];

    // إذا كان الرابط يحتوي على توكن استعادة أو معاملات الدخول المباشر
    if (token != null ||
        sessionId != null ||
        _capturedParams!['type'] == 'recovery') {
      _isRedirecting = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleIncomingLink();
    });
  }

  Map<String, String> _extractParams() {
    final fullUri = Uri.base;
    Map<String, String> params = Map.from(fullUri.queryParameters);

    if (fullUri.pathSegments.contains('join')) {
      final joinIndex = fullUri.pathSegments.indexOf('join');
      if (joinIndex < fullUri.pathSegments.length - 1) {
        params['lms_id'] = fullUri.pathSegments[joinIndex + 1];
      }
    }

    if (fullUri.fragment.isNotEmpty) {
      String fragment = fullUri.fragment;
      if (fragment.contains('?')) {
        fragment = fragment.split('?').last;
      }
      if (fragment.startsWith('/')) {
         if (fragment.contains('?')) {
           fragment = fragment.split('?').last;
         } else {
           fragment = "";
         }
      }
      
      if (fragment.isNotEmpty) {
        params.addAll(Uri.splitQueryString(fragment));
      }
    }
    return params;
  }

  Future<void> _handleIncomingLink() async {
    if (_linkProcessed) return;

    final params = _capturedParams ?? _extractParams();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // 1. معالجة رابط إعادة تعيين كلمة المرور
      if (params['type'] == 'recovery') {
        _linkProcessed = true;
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.resetPassword, (route) => false);
        }
        return;
      }

      // 2. معالجة الدخول التلقائي (LTI أو غيره)
      final token = params['token'] ?? params['access_token'];
      if (token != null) {
        try {
          if (mounted) setState(() => _isRedirecting = true);
          await Supabase.instance.client.auth.setSession(token);
          // الانتظار قليلاً لضمان تحديث مستمع حالة تسجيل الدخول
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint("AutoLogin Error: $e");
        }
      }

      // 3. معالجة تحديث الملف الشخصي في حالة الدخول القادم من Blackboard
      final externalId = params['external_id'] ?? params['externalId'];
      final role = params['role'];
      final fullName = params['full_name'] ?? params['userName'] ?? params['username'];

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && externalId != null) {
        final email = params['email'] ?? currentUser.email ?? '${externalId}@blackboard.com';
        await authProvider.handleExternalAuth(
          externalId: externalId,
          email: email,
          fullName: fullName ?? 'مستخدم Blackboard',
          role: role ?? 'student',
        );
      }

      // 4. معالجة الدخول المباشر للقاعات
      final sessionId = params['sessionId'] ?? params['session_id'] ?? params['lms_id'];
      if (sessionId != null && currentUser != null) {
        _linkProcessed = true;
        if (mounted) setState(() => _isRedirecting = true);

        final dbService = Provider.of<DatabaseService>(context, listen: false);
        
        // محاولة جلب الجلسة أولاً بـ ID الجلسة المباشر، ثم بـ lmsId
        var sessionData = await dbService.getSessionById(sessionId);
        sessionData ??= await dbService.getSessionByLmsId(sessionId);

        if (sessionData != null && mounted) {
          final isTeacherRole = (role == 'teacher' || authProvider.role == 'teacher');
          final userId = currentUser.id;

          if (!isTeacherRole) {
            await dbService.enrollStudentBySessionId(userId, sessionData['id']);
          }

          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.videoRoom,
            (route) => false,
            arguments: {
              'roomName': 'room_${sessionData['id']}',
              'title': sessionData['subject_name'] ?? 'قاعة تعليمية',
              'userName': authProvider.profile?['full_name'] ?? fullName ?? 'User',
              'userId': userId,
              'isTeacher': isTeacherRole,
              'sessionId': sessionData['id'],
            },
          );
          return;
        }
      }
    } catch (e) {
      debugPrint("Auth Redirection Flow Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isRedirecting = false;
          _linkProcessed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isRedirecting || authProvider.isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF102A43)),
              const SizedBox(height: 32),
              const Icon(Icons.security_rounded, size: 48, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text("جاري التحقق من الهوية...",
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
              const Text("سيتم توجيهك الآن تلقائياً",
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
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
