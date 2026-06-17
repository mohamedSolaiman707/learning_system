import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  User? _user;
  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  bool _hasSeenTour = false;
  bool _hasSeenVideoTour = false;

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get hasSeenTour => _hasSeenTour;
  bool get hasSeenVideoTour => _hasSeenVideoTour;

  String get role => _profile?['role'] ?? _user?.userMetadata?['role'] ?? 'student';
  bool get isTeacher => role == 'teacher';
  bool get isAdmin => role == 'admin';

  String? get externalId => _profile?['external_id'];

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _user = _supabase.auth.currentUser;
    if (_user != null) {
      _initializeProfileFromMetadata();
      await refreshProfile();
      await _checkTourStatus();
    }

    _supabase.auth.onAuthStateChange.listen((data) async {
      final newUser = data.session?.user;
      if (newUser != null) {
        if (newUser.id != _user?.id) {
          _user = newUser;
          _initializeProfileFromMetadata();
          await refreshProfile();
          await _checkTourStatus();
        }
      } else {
        _user = null;
        _profile = null;
        _hasSeenTour = false;
        _hasSeenVideoTour = false;
        notifyListeners();
      }
    });
  }

  Future<void> _checkTourStatus() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    _hasSeenTour = prefs.getBool('tour_seen_${_user!.id}') ?? false;
    _hasSeenVideoTour = prefs.getBool('video_tour_seen_${_user!.id}') ?? false;
    notifyListeners();
  }

  Future<void> completeTour() async {
    if (_user == null) return;
    _hasSeenTour = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tour_seen_${_user!.id}', true);
    notifyListeners();
  }

  Future<void> completeVideoTour() async {
    if (_user == null) return;
    _hasSeenVideoTour = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('video_tour_seen_${_user!.id}', true);
    notifyListeners();
  }

  void _initializeProfileFromMetadata() {
    if (_user == null) return;
    _profile = {
      'id': _user!.id,
      'full_name': _user!.userMetadata?['full_name'] ?? 'مستخدم جديد',
      'role': _user!.userMetadata?['role'] ?? 'student',
      'email': _user!.email,
      'avatar_url': _user!.userMetadata?['avatar_url'],
    };
    notifyListeners();
  }

  Future<void> refreshProfile() async {
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
      await refreshProfile();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    if (_user == null) return;
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> uploadAvatar(Uint8List bytes, String fileName) async {
    if (_user == null) return null;
    try {
      final fileExt = fileName.split('.').last;
      final path = '${_user!.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(path);

      await updateProfile({'avatar_url': imageUrl});
      return imageUrl;
    } catch (e) {
      debugPrint("Upload Error: $e");
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
        await _checkTourStatus();
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
        await refreshProfile();
        await _checkTourStatus();
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
    _hasSeenTour = false;
    _hasSeenVideoTour = false;
    notifyListeners();
  }
}
