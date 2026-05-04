import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const Map<String, Map<String, String>> _localizedValues = {
    'ar': {
      'login': 'تسجيل الدخول',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'welcome_back': 'مرحباً بك مجدداً',
      'admin_dashboard': 'لوحة تحكم المسؤول',
      'student': 'طالب',
      'teacher': 'مدرس',
      'settings': 'الإعدادات',
      'logout': 'تسجيل الخروج',
      'theme_mode': 'وضع المظهر',
      'dark_mode': 'الوضع الداكن',
      'light_mode': 'الوضع الفاتح',
      'language': 'اللغة',
    },
    'en': {
      'login': 'Login',
      'email': 'Email',
      'password': 'Password',
      'welcome_back': 'Welcome Back',
      'admin_dashboard': 'Admin Dashboard',
      'student': 'Student',
      'teacher': 'Teacher',
      'settings': 'Settings',
      'logout': 'Logout',
      'theme_mode': 'Theme Mode',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'language': 'Language',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension TranslateExtension on BuildContext {
  String translate(String key) => AppLocalizations.of(this)?.translate(key) ?? key;
}
