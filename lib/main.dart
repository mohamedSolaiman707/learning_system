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

  @override
  void initState() {
    super.initState();
    
    final params = _extractParams();
    final token = params['token'] ?? params['access_token'];
    final sessionId = params['sessionId'] ?? params['session_id'] ?? params['lms_id'];

    if (token != null || sessionId != null || params['type'] == 'recovery') {
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
      final fragment = fullUri.fragment;
      String pathPart = fragment;
      String queryPart = '';
      
      int queryIndex = fragment.indexOf('?');
      if (queryIndex != -1) {
        pathPart = fragment.substring(0, queryIndex);
        queryPart = fragment.substring(queryIndex + 1);
      }
      
      params['__internal_path'] = pathPart;
      
      if (queryPart.isNotEmpty) {
        params.addAll(Uri.splitQueryString(queryPart));
      } else if (pathPart.contains('=') && !pathPart.startsWith('/')) {
        params.addAll(Uri.splitQueryString(pathPart));
      }
    }
    return params;
  }

  Future<void> _handleIncomingLink() async {
    if (_linkProcessed) return;

    final params = _extractParams();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (params['type'] == 'recovery') {
        _linkProcessed = true;
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.resetPassword, (route) => false);
        }
        return;
      }

      final token = params['token'] ?? params['access_token'];
      if (token != null) {
        try {
          if (mounted) setState(() => _isRedirecting = true);
          await Supabase.instance.client.auth.setSession(token);
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint("AutoLogin Error: $e");
        }
      }

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
         if (mounted) setState(() => _isRedirecting = false);
         return;
      }

      // إجبار النظام على تحميل البروفايل بالكامل للتأكد من رتبة المستخدم (مدرس أم طالب)
      if (authProvider.profile == null || authProvider.role.isEmpty) {
        await authProvider.refreshProfile();
      }

      // اكتشاف المسارات الخاصة بالأدوات من الرابط الكامل والـ Fragment
      final String fullUrl = Uri.base.toString().toLowerCase();
      final String internalPath = (params['__internal_path'] ?? '').toLowerCase();
      
      final bool isPublisherRoute = fullUrl.contains('room-publisher') || internalPath.contains('room-publisher');
      final bool isWallRoute = fullUrl.contains('wall-display') || internalPath.contains('wall-display');
      
      final String sessionId = params['sessionId'] ?? params['session_id'] ?? params['lms_id'] ?? "";

      if (sessionId.isNotEmpty) {
        _linkProcessed = true;
        if (mounted) setState(() => _isRedirecting = true);

        final dbService = Provider.of<DatabaseService>(context, listen: false);
        var sessionData = await dbService.getSessionById(sessionId);
        sessionData ??= await dbService.getSessionByLmsId(sessionId);

        if (sessionData != null && mounted) {
          // 1. التوجيه لمسارات الأدوات (Publisher / Wall) - أولوية مطلقة
          if (isPublisherRoute || isWallRoute) {
            final targetRoute = isPublisherRoute ? AppRoutes.roomPublisher : AppRoutes.wallDisplay;
            
            Navigator.of(context).pushNamedAndRemoveUntil(
              targetRoute,
              (route) => false,
              arguments: {
                ...params,
                'sessionId': sessionData['id'],
                'roomName': params['roomName'] ?? 'room_${sessionData['id']}',
                'zone': params['zone'] ?? 'screen_1',
              },
            );
            return;
          }

          // 2. التوجيه الافتراضي للقاعة التعليمية
          final String userRole = authProvider.role.toLowerCase();
          final bool isTeacherRole = (params['role'] == 'teacher' || userRole == 'teacher' || authProvider.profile?['role'] == 'teacher');
          final String userName = authProvider.profile?['full_name'] ?? params['userName'] ?? params['username'] ?? 'مستخدم';

          if (!isTeacherRole) {
            // تسجيل حضور الطالب في قاعدة البيانات
            await dbService.enrollStudentBySessionId(currentUser.id, sessionData['id']);
          }

          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.videoRoom,
            (route) => false,
            arguments: {
              'roomName': params['roomName'] ?? 'room_${sessionData['id']}',
              'title': params['title'] ?? sessionData['subject_name'] ?? 'قاعة تعليمية',
              'userName': userName,
              'userId': currentUser.id,
              'isTeacher': isTeacherRole,
              'sessionId': sessionData['id'],
            },
          );
          return;
        }
      }
    } catch (e) {
      debugPrint("Auth Redirection Error: $e");
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
