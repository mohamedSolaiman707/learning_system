import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('ar', 'EG');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (!['ar', 'en'].contains(locale.languageCode)) return;
    _locale = locale;
    notifyListeners();
  }

  void clearLocale() {
    _locale = const Locale('ar', 'EG');
    notifyListeners();
  }
}
