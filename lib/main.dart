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
  Map<String, String>? _capturedParams;

  @override
  void initState() {
    super.initState();
    _capturedParams = _extractParams();

    if (_capturedParams!.containsKey('access_token') || 
        _capturedParams!.containsKey('session_id') || 
        _capturedParams!.containsKey('sessionId') || 
        _capturedParams!.containsKey('lms_id')) {
      _isRedirecting = true;
    }
    
    // مراقبة حالة المصادقة لمعالجة الرابط فور تسجيل الدخول
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndProcessLink();
    });
  }

  Map<String, String> _extractParams() {
    final fullUri = Uri.base;
    Map<String, String> params = Map.from(fullUri.queryParameters);

    // معالجة البارامترات في الـ Fragment (لأن Flutter Web يستخدم Hash strategy غالباً)
    if (fullUri.fragment.isNotEmpty) {
      String fragment = fullUri.fragment;
      if (fragment.contains('?')) {
        final queryPart = fragment.split('?').last;
        params.addAll(Uri.splitQueryString(queryPart));
      } else if (fragment.startsWith('/')) {
        // دعم لروابط مثل /#/live?sessionId=...
        final parts = fragment.split('?');
        if (parts.length > 1) {
          params.addAll(Uri.splitQueryString(parts.last));
        }
      }
    }
    return params;
  }

  void _checkAndProcessLink() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // إذا تغيرت حالة المستخدم، نحاول معالجة الرابط
    authProvider.addListener(_handleAuthChange);
    
    // محاولة أولية
    _handleIncomingLink();
  }

  void _handleAuthChange() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated && !_linkProcessed) {
      _handleIncomingLink();
    }
  }

  @override
  void dispose() {
    // إزالة المستمع لتجنب تسريب الذاكرة
    Provider.of<AuthProvider>(context, listen: false).removeListener(_handleAuthChange);
    super.dispose();
  }

  Future<void> _handleIncomingLink() async {
    if (_linkProcessed) return;

    final params = _capturedParams ?? _extractParams();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // 1. معالجة التوكين إذا وجد
    final accessToken = params['access_token'];
    if (accessToken != null && !authProvider.isAuthenticated) {
      try {
        await Supabase.instance.client.auth.setSession(accessToken);
        // ننتظر قليلاً ليتم تحديث الـ AuthProvider
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        debugPrint("SetSession Error: $e");
      }
    }

    // 2. التحقق من وجود معرف الجلسة
    final sessionId = params['session_id'] ?? params['sessionId'];
    final lmsId = params['lms_id'];

    if (sessionId == null && lmsId == null) {
      if (mounted) setState(() => _isRedirecting = false);
      return;
    }

    // 3. الانتظار حتى يكتمل تسجيل الدخول
    if (!authProvider.isAuthenticated) {
      if (mounted) setState(() => _isRedirecting = false);
      return;
    }

    // 4. معالجة الرابط وتوجيه المستخدم
    _linkProcessed = true;
    if (mounted) setState(() => _isRedirecting = true);

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final sessionData = sessionId != null
          ? await dbService.getSessionById(sessionId)
          : await dbService.getSessionByLmsId(lmsId!);

      if (sessionData != null && mounted) {
        // تسجيل الطالب تلقائياً في الحصة لضمان ظهوره في كشف الحضور
        if (authProvider.role == 'student') {
          await dbService.enrollStudentBySessionId(authProvider.user!.id, sessionData['id']);
        }

        String? roomName;
        var roomsData = sessionData['rooms'];
        if (roomsData != null) {
          if (roomsData is List && roomsData.isNotEmpty) {
            roomName = roomsData[0]['room_name'];
          } else if (roomsData is Map) {
            roomName = roomsData['room_name'];
          }
        }

        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.videoRoom,
          (route) => false,
          arguments: {
            'roomName': roomName ?? 'room_${sessionData['id']}',
            'title': sessionData['subject_name'] ?? sessionData['title'] ?? 'قاعة تعليمية',
            'userName': authProvider.profile?['full_name'] ?? 'User',
            'userId': authProvider.user?.id ?? '',
            'isTeacher': authProvider.role == 'teacher',
            'sessionId': sessionData['id'],
          },
        );
        return;
      }
    } catch (e) {
      debugPrint("Link Processing Error: $e");
    }
    
    if (mounted) setState(() => _isRedirecting = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isRedirecting || authProvider.isLoading) {
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
