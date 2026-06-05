import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('ar', 'EG');
  static const String _localeKey = 'selected_locale';

  Locale get locale => _locale;

  LocaleProvider() {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString(_localeKey);
    if (languageCode != null) {
      _locale = Locale(languageCode, languageCode == 'ar' ? 'EG' : 'US');
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!['ar', 'en'].contains(locale.languageCode)) return;
    _locale = locale;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  Future<void> toggleLocale() async {
    final newLocale = _locale.languageCode == 'ar' 
        ? const Locale('en', 'US') 
        : const Locale('ar', 'EG');
    await setLocale(newLocale);
  }
}
