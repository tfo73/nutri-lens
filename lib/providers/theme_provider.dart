import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'isDarkMode';
  bool _isDarkMode = true; // Varsayılan: koyu tema

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_key) ?? true; // Varsayılan: koyu tema
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDarkMode);
  }

  void setDark(bool value) {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_key, _isDarkMode));
  }
}
