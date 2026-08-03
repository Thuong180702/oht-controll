import 'auth_cloud_service.dart';
import 'session_storage.dart';

class AuthStorage {
  static const defaultUsername = 'Thaco';
  static const defaultPassword = 'Thaco@1234';
  static const _passwordKey = 'admin_password';
  static const _activeSessionPasswordKey = 'active_session_password';

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

  /// Called after successful login to record the active session password.
  static Future<void> saveActiveSessionPassword(String password) async {
    await SessionStorage.setItem(_activeSessionPasswordKey, password);
    await SessionStorage.setItem(_passwordKey, password);
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

  /// Validates whether the active local session password matches the live Cloudflare KV password.
  /// If online and password changed on Cloudflare KV from another device, returns false.
  static Future<bool> isSessionValid() async {
    final activePassword = SessionStorage.getItem(_activeSessionPasswordKey) ??
        SessionStorage.getItem(_passwordKey) ??
        defaultPassword;

    final remotePassword =
        await AuthCloudService.fetchRemotePassword(username: defaultUsername);

    if (remotePassword != null && remotePassword.isNotEmpty) {
      if (remotePassword != activePassword) {
        // Remote password on Cloudflare KV was changed from another device!
        return false;
      }
    }
    return true;
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
      await SessionStorage.setItem(_activeSessionPasswordKey, newPassword);
    }
    return result;
  }
}
