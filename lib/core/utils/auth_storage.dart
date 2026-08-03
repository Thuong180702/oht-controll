import 'auth_cloud_service.dart';
import 'session_storage.dart';

class AuthStorage {
  static const defaultUsername = 'Thaco';
  static const defaultPassword = 'Thaco@1234';
  static const _passwordKey = 'admin_password';

  /// Seeds local password and triggers background Cloudflare KV sync.
  static Future<void> ensureSeeded() async {
    final existing = SessionStorage.getItem(_passwordKey);
    if (existing == null || existing.isEmpty) {
      await SessionStorage.setItem(_passwordKey, defaultPassword);
    }
    // Background sync with Cloudflare KV (non-blocking)
    AuthCloudService.fetchRemotePassword(username: defaultUsername);
  }

  /// Returns stored password instantly, while syncing with Cloudflare KV in background.
  static Future<String> getPassword() async {
    final stored = SessionStorage.getItem(_passwordKey);
    // Background refresh from Cloudflare KV
    AuthCloudService.fetchRemotePassword(username: defaultUsername);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return defaultPassword;
  }

  /// Synchronous instant password getter for UI widgets
  static String getPasswordSync() {
    final stored = SessionStorage.getItem(_passwordKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return defaultPassword;
  }

  static Future<bool> setPassword(String newPassword, {String? oldPassword}) async {
    final currentLocal = SessionStorage.getItem(_passwordKey) ?? defaultPassword;
    // 1. Save to local storage INSTANTLY so UI never freezes
    await SessionStorage.setItem(_passwordKey, newPassword);

    // 2. Push to Cloudflare KV in background so all other devices sync
    AuthCloudService.pushRemotePassword(
      username: defaultUsername,
      oldPassword: oldPassword ?? currentLocal,
      newPassword: newPassword,
    );
    return true;
  }
}
