// Simplified widget test for MyApp with required providers
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:learning_by_video_call/main.dart';
import 'package:learning_by_video_call/core/providers/theme_provider.dart';
import 'package:learning_by_video_call/core/providers/locale_provider.dart';
import 'package:learning_by_video_call/core/providers/auth_provider.dart';
import 'package:learning_by_video_call/core/services/database_service.dart';
import 'package:learning_by_video_call/core/services/cache_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Minimal mock AuthProvider implementing all required members
class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  // Getters
  @override
  User? get user => null;
  @override
  Map<String, dynamic>? get profile => null;
  @override
  bool get isLoading => false;
  @override
  bool get isAuthenticated => true;
  @override
  bool get hasSeenTour => false;
  @override
  bool get hasSeenVideoTour => false;
  @override
  String get role => 'student';
  @override
  bool get isTeacher => false;
  @override
  bool get isAdmin => false;
  @override
  String? get externalId => null;

  // Methods - stub implementations
  @override
  Future<void> completeTour() async {}
  @override
  Future<void> completeVideoTour() async {}
  @override
  Future<void> refreshProfile() async {}
  @override
  Future<void> updateProfile(Map<String, dynamic> data) async {}
  @override
  Future<void> updatePassword(String newPassword) async {}
  @override
  Future<String?> uploadAvatar(Uint8List bytes, String fileName) async => null;
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<bool> isEmailAvailable(String email) async => true;
  @override
  Future<bool> handleExternalAuth({required String externalId, required String email, required String fullName, required String role}) async => false;
  @override
  Future<bool> register({required String email, required String password, required String fullName}) async => true;
  @override
  Future<bool> login(String email, String password) async => true;
  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('MyApp builds with providers', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MockAuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          Provider(create: (_) => DatabaseService()),
          Provider(create: (_) => CacheService()),
        ],
        child: const MyApp(),
      ),
    );
    expect(find.byType(MyApp), findsOneWidget);
  });
}
