import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/prefs_service.dart';

/// Tema Durumu Provider'ı (ThemeModeNotifier)
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _key = 'app_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadThemeMode();
  }

  /// SharedPreferences'tan kaydedilmiş temayı yükle
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await PrefsService.instance();
      final savedTheme = prefs?.getString(_key);
      if (savedTheme != null) {
        switch (savedTheme) {
          case 'light':
            state = ThemeMode.light;
            break;
          case 'dark':
            state = ThemeMode.dark;
            break;
          case 'system':
            state = ThemeMode.system;
            break;
        }
      }
    } catch (_) {
      // Hata durumunda varsayılan Dark Mode kalır
    }
  }

  /// Temayı değiştir ve yerel hafızaya kaydet
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) return;
      String modeStr = 'dark';
      if (mode == ThemeMode.light) modeStr = 'light';
      if (mode == ThemeMode.system) modeStr = 'system';
      await prefs.setString(_key, modeStr);
    } catch (_) {}
  }
}
