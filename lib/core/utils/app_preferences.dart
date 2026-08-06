import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_storage.dart';

class AppPreferences {
  const AppPreferences._();

  static Future<void> init() async {
    await SessionStorage.init();
    await SharedPreferences.getInstance();
  }

  static const languageCodeKey = 'oht_language_code';
  static const themeModeKey = 'oht_theme_mode';
  static const loggedInUserKey = 'oht_logged_in_username';
  static const savedScreenKey = 'oht_saved_screen';
  static const savedProtocolKey = 'oht_saved_protocol';
  static const savedWebSocketUrlKey = 'oht_saved_ws_url';

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

  // ─── Session Persistence (Powered by SessionStorage / localStorage) ────

  static String? getLoggedInUser() {
    return SessionStorage.getItem(loggedInUserKey);
  }

  static Future<void> setLoggedInUser(String? username) async {
    if (username == null || username.trim().isEmpty) {
      await SessionStorage.removeItem(loggedInUserKey);
    } else {
      await SessionStorage.setItem(loggedInUserKey, username.trim());
    }
  }

  static String? getSavedScreen() {
    return SessionStorage.getItem(savedScreenKey);
  }

  static Future<void> setSavedScreen(String screenName) async {
    await SessionStorage.setItem(savedScreenKey, screenName);
  }

  static String? getSavedProtocol() {
    return SessionStorage.getItem(savedProtocolKey);
  }

  static Future<void> setSavedProtocol(String protocolName) async {
    await SessionStorage.setItem(savedProtocolKey, protocolName);
  }

  static String? getSavedWebSocketUrl() {
    return SessionStorage.getItem(savedWebSocketUrlKey);
  }

  static Future<void> setSavedWebSocketUrl(String url) async {
    await SessionStorage.setItem(savedWebSocketUrlKey, url);
  }

  static Future<void> clearSession() async {
    await SessionStorage.removeItem(loggedInUserKey);
    await SessionStorage.removeItem(savedScreenKey);
  }
}
