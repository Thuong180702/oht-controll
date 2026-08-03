import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const defaultUsername = 'Thaco';
  static const defaultPassword = 'Thaco@1234';
  static const _passwordKey = 'admin_password';

  /// Seeds the default password on first run.
  // TODO: Migrate to flutter_secure_storage for production builds.
  // ponytail: SharedPreferences stores plaintext — acceptable for factory floor
  // tablets behind firewall, but upgrade to flutter_secure_storage before
  // deploying to unmanaged devices.
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
