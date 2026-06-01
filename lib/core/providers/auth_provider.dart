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

  // ميزة جديدة: تهيئة الملف الشخصي من بيانات Auth Metadata لتفادي فراغ البيانات
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
      } else {
        debugPrint("Profile not found in DB, using metadata fallback.");
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
        _user = response.user;
        
        final profileData = {
          'id': response.user!.id,
          'full_name': fullName,
          'email': email,
          'phone_number': phoneNumber,
          'role': 'student',
        };

        // تعيين البيانات محلياً فوراً
        _profile = profileData;
        notifyListeners();

        // إنشاء السجل في قاعدة البيانات في الخلفية
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
        _initializeProfileFromMetadata(); // تحميل البيانات الأولية فوراً
        await _loadProfile(); // ثم جلب البيانات الكاملة من DB
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
