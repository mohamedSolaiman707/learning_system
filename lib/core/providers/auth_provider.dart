import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  User? _user;
  Map<String, dynamic>? _profile;
  bool _isLoading = false;

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  String get role => _profile?['role'] ?? 'student';
  String? get externalId => _profile?['external_id'];

  AuthProvider() {
    _user = _supabase.auth.currentUser;
    if (_user != null) {
      _loadProfile();
    }
    
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      if (_user != null) {
        _loadProfile();
      } else {
        _profile = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .single();
      _profile = data;
      _profile?['email'] = _user?.email;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (_user == null) return;
    try {
      await _supabase.from('profiles').update(data).eq('id', _user!.id);
      await _loadProfile();
    } catch (e) {
      rethrow;
    }
  }

  // ميزة استعادة كلمة المرور لتحسين الـ UX
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  // ميزة UX: التحقق من توفر البريد الإلكتروني قبل التسجيل
  Future<bool> isEmailAvailable(String email) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      return res == null; // إذا كان null يعني البريد متاح
    } catch (e) {
      debugPrint("Check email availability error: $e");
      return true;
    }
  }

  // التكامل مع الأنظمة الخارجية (Blackboard)
  Future<bool> handleExternalAuth(String externalId, String email, String fullName, String role) async {
    _isLoading = true;
    notifyListeners();
    try {
      final existingProfile = await _supabase
          .from('profiles')
          .select()
          .eq('external_id', externalId)
          .maybeSingle();

      if (existingProfile != null) {
        await _loadProfile();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("External Auth Error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': 'student'},
      );

      if (response.user != null) {
        await _supabase.from('profiles').upsert({
          'id': response.user!.id,
          'full_name': fullName,
          'email': email,
          'phone_number': phoneNumber,
          'role': 'student',
        });
        
        if (response.session != null) {
          _user = response.user;
          await _loadProfile();
        }
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _user = response.user;
      if (_user != null) {
        await _loadProfile();
      }
      return true;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _user = null;
    _profile = null;
    notifyListeners();
  }
}
