import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  const AppPreferences._();

  static const languageCodeKey = 'oht_language_code';
  static const themeModeKey = 'oht_theme_mode';

  static const defaultLanguageCode = 'vi';
  static const defaultThemeMode = ThemeMode.light;

  static Future<String> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(languageCodeKey);
    return value == 'en' || value == 'vi' ? value! : defaultLanguageCode;
  }

  static Future<void> setLanguageCode(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      languageCodeKey,
      languageCode == 'en' ? 'en' : defaultLanguageCode,
    );
  }

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(themeModeKey)) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => defaultThemeMode,
    };
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      themeModeKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}
