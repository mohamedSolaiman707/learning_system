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

  AuthProvider() {
    _user = _supabase.auth.currentUser;
    if (_user != null) {
      _loadProfile();
    }
    
    // الاستماع لتغييرات حالة المصادقة
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
      // إضافة البريد الإلكتروني للملف الشخصي للعرض فقط
      _profile?['email'] = _user?.email;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  // تحديث بيانات الملف الشخصي
  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (_user == null) return;
    try {
      await _supabase.from('profiles').update(data).eq('id', _user!.id);
      await _loadProfile(); // إعادة تحميل البيانات بعد التحديث
    } catch (e) {
      rethrow;
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
