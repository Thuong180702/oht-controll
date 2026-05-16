import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const defaultUsername = 'Thaco';
  static const defaultPassword = 'Thaco@1234';
  static const _passwordKey = 'admin_password';

  static Future<void> ensureSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_passwordKey)) {
      await prefs.setString(_passwordKey, defaultPassword);
    }
  }

  static Future<String> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_passwordKey) ?? defaultPassword;
  }

  static Future<void> setPassword(String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passwordKey, newPassword);
  }
}
