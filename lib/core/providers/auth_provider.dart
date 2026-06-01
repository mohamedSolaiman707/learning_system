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
      final newUser = data.session?.user;
      if (newUser != null && newUser.id != _user?.id) {
        _user = newUser;
        _loadProfile();
      } else if (newUser == null) {
        _user = null;
        _profile = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadProfile() async {
    if (_user == null) return;
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .maybeSingle();

      if (data != null) {
        _profile = data;
        _profile?['email'] = _user?.email;
        notifyListeners();
      } else {
        debugPrint("Profile not found for user: ${_user!.id}");
      }
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

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> isEmailAvailable(String email) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      return res == null;
    } catch (e) {
      debugPrint("Check email availability error: $e");
      return true;
    }
  }

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
        _profile = existingProfile;
        _user = _supabase.auth.currentUser;
        notifyListeners();
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
        final profileData = {
          'id': response.user!.id,
          'full_name': fullName,
          'email': email,
          'phone_number': phoneNumber,
          'role': 'student',
        };

        // إنشاء الملف الشخصي في قاعدة البيانات
        await _supabase.from('profiles').upsert(profileData);
        
        _user = response.user;
        // تحديث محلي فوري لضمان ظهور الاسم في الصفحة الرئيسية فوراً
        _profile = profileData;
        notifyListeners();
        
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
      
      if (response.user != null) {
        _user = response.user;
        await _loadProfile();
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

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _user = null;
    _profile = null;
    notifyListeners();
  }
}
