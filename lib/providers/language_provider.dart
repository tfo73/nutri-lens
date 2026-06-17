import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const _key = 'locale';
  Locale _currentLocale = const Locale('tr');

  Locale get currentLocale => _currentLocale;
  bool get isTurkish => _currentLocale.languageCode == 'tr';

  LanguageProvider() {
    _initLocale();
  }

  void _initLocale() {
    try {
      final systemLocale = ui.PlatformDispatcher.instance.locale.languageCode;
      final defaultLang = (systemLocale == 'tr') ? 'tr' : 'en';
      _currentLocale = Locale(defaultLang);
    } catch (_) {
      _currentLocale = const Locale('tr');
    }
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) {
      _currentLocale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> toggleLanguage() async {
    _currentLocale = isTurkish ? const Locale('en') : const Locale('tr');
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _currentLocale.languageCode);
  }
}
