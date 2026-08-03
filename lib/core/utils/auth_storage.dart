import 'auth_cloud_service.dart';
import 'session_storage.dart';

class AuthStorage {
  static const defaultUsername = 'Thaco';
  static const defaultPassword = 'Thaco@1234';
  static const _passwordKey = 'admin_password';

  /// Seeds local password and fetches latest remote password from Cloudflare KV.
  static Future<void> ensureSeeded() async {
    final existing = SessionStorage.getItem(_passwordKey);
    if (existing == null || existing.isEmpty) {
      await SessionStorage.setItem(_passwordKey, defaultPassword);
    }
    // Await live password sync from Cloudflare KV
    await AuthCloudService.fetchRemotePassword(username: defaultUsername);
  }

  static Future<String> getPassword() async {
    // 1. Await live remote password from Cloudflare KV
    final remotePassword =
        await AuthCloudService.fetchRemotePassword(username: defaultUsername);
    if (remotePassword != null && remotePassword.isNotEmpty) {
      return remotePassword;
    }

    // 2. Fallback to local session storage if offline
    final stored = SessionStorage.getItem(_passwordKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return defaultPassword;
  }

  static Future<bool> setPassword(String newPassword, {String? oldPassword}) async {
    final currentLocal = SessionStorage.getItem(_passwordKey) ?? defaultPassword;
    await SessionStorage.setItem(_passwordKey, newPassword);

    // Push to Cloudflare KV so all other devices receive the updated password instantly
    final synced = await AuthCloudService.pushRemotePassword(
      username: defaultUsername,
      oldPassword: oldPassword ?? currentLocal,
      newPassword: newPassword,
    );
    return synced;
  }
}
