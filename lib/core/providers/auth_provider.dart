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

  // تحديد الـ Role بدقة (الأولوية للـ Profile ثم الـ Metadata القادم من Blackboard/Auth)
  String get role => _profile?['role'] ?? _user?.userMetadata?['role'] ?? 'student';
  String? get externalId => _profile?['external_id'];

  AuthProvider() {
    _user = _supabase.auth.currentUser;
    if (_user != null) {
      _initializeProfileFromMetadata();
      _loadProfile();
    }
    
    _supabase.auth.onAuthStateChange.listen((data) {
      final newUser = data.session?.user;
      if (newUser != null) {
        if (newUser.id != _user?.id) {
          _user = newUser;
          _initializeProfileFromMetadata();
          _loadProfile();
        }
      } else {
        _user = null;
        _profile = null;
        notifyListeners();
      }
    });
  }

  // تهيئة سريعة للبيانات من الـ Metadata لمنع ظهور "الطالب" أو الـ Loading المستمر
  void _initializeProfileFromMetadata() {
    if (_user == null) return;
    _profile = {
      'id': _user!.id,
      'full_name': _user!.userMetadata?['full_name'] ?? 'مستخدم جديد',
      'role': _user!.userMetadata?['role'] ?? 'student',
      'email': _user!.email,
    };
    notifyListeners();
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
        _profile = Map<String, dynamic>.from(data);
        _profile?['email'] = _user?.email;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading profile from DB: $e");
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

  // دالة مطورة للتكامل مع Blackboard (تنشئ الحساب تلقائياً إذا لم يوجد)
  Future<bool> handleExternalAuth({
    required String externalId,
    required String email,
    required String fullName,
    required String role,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = _supabase.auth.currentUser;
      if (_user == null) return false;

      final profileData = {
        'id': _user!.id,
        'external_id': externalId,
        'full_name': fullName,
        'email': email,
        'role': role,
      };

      // استخدام upsert لضمان إنشاء أو تحديث بيانات المستخدم القادم من Blackboard
      await _supabase.from('profiles').upsert(profileData);
      
      _profile = profileData;
      notifyListeners();
      return true;
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
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName, 
          'role': 'student',
        },
      );

      if (response.user != null) {
        _user = response.user;
        
        final profileData = {
          'id': response.user!.id,
          'full_name': fullName,
          'email': email,
          'role': 'student',
        };

        _profile = profileData;
        notifyListeners();

        await _supabase.from('profiles').upsert(profileData);
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
        _initializeProfileFromMetadata(); 
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
