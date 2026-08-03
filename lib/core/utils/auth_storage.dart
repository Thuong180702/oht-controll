import 'auth_cloud_service.dart';
import 'session_storage.dart';

class AuthStorage {
  static const defaultUsername = 'Thaco';
  static const defaultPassword = 'Thaco@1234';
  static const _passwordKey = 'admin_password';

  /// Seeds local password and background syncs with Cloudflare KV.
  static Future<void> ensureSeeded() async {
    final existing = SessionStorage.getItem(_passwordKey);
    if (existing == null || existing.isEmpty) {
      await SessionStorage.setItem(_passwordKey, defaultPassword);
    }
    // Background sync with Cloudflare KV
    AuthCloudService.fetchRemotePassword(username: defaultUsername);
  }

  /// 1. Online: Fetch live password from Cloudflare KV & update local cache.
  /// 2. Offline: Fallback to local stored password.
  static Future<String> getPasswordForLogin() async {
    final remotePassword =
        await AuthCloudService.fetchRemotePassword(username: defaultUsername);
    if (remotePassword != null && remotePassword.isNotEmpty) {
      await SessionStorage.setItem(_passwordKey, remotePassword);
      return remotePassword;
    }

    final stored = SessionStorage.getItem(_passwordKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return defaultPassword;
  }

  static Future<String> getPassword() => getPasswordForLogin();

  /// Synchronous instant password getter for offline display/cache
  static String getPasswordSync() {
    final stored = SessionStorage.getItem(_passwordKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return defaultPassword;
  }

  /// Change password: Requires online connection to sync with Cloudflare KV.
  static Future<({bool success, String message})> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final result = await AuthCloudService.pushRemotePassword(
      username: defaultUsername,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );

    if (result.success) {
      await SessionStorage.setItem(_passwordKey, newPassword);
    }
    return result;
  }
}
