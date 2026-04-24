import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts light / dark [ThemeMode].
class ThemeModeController extends ChangeNotifier {
  static const _kDark = 'app_theme_is_dark';

  bool _isDark = false;
  bool get isDark => _isDark;
  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _isDark = p.getBool(_kDark) ?? false;
    notifyListeners();
  }

  /// Smooth toggle with optional callback after first frame.
  Future<void> setDark(bool value) async {
    if (value == _isDark) return;
    _isDark = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDark, _isDark);
  }

  Future<void> toggle() => setDark(!_isDark);
}
