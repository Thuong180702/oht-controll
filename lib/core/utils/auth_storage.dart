import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_account.dart';
import 'auth_cloud_service.dart';
import 'session_storage.dart';

class AuthStorage {
  static const defaultUsername = 'Thaco';
  static const defaultPassword = 'Thaco@1234';
  
  static const defaultAdminUsername = 'admin';
  static const defaultAdminPassword = 'admin@1234';

  static const _accountsListKey = 'oht_user_accounts_v2';
  static const _passwordKey = 'admin_password';
  static const _activeSessionPasswordKey = 'active_session_password';
  static const _activeSessionRoleKey = 'active_session_role';

  /// Pre-seeded default user accounts
  static final List<UserAccount> _defaultAccounts = [
    UserAccount(
      username: defaultAdminUsername,
      password: defaultAdminPassword,
      role: 0, // Admin
      isLocked: false,
      createdAt: '2026-01-01T00:00:00.000Z',
    ),
    UserAccount(
      username: defaultUsername,
      password: defaultPassword,
      role: 1, // User điều khiển (Operator)
      isLocked: false,
      createdAt: '2026-01-01T00:00:00.000Z',
    ),
  ];

  /// Ensures default accounts exist and syncs background session
  static Future<void> ensureSeeded() async {
    final accounts = getAccounts();
    if (accounts.isEmpty) {
      await _saveAccountsList(_defaultAccounts);
    } else {
      // Ensure admin exists
      if (!accounts.any((a) => a.username.toLowerCase() == defaultAdminUsername)) {
        accounts.insert(0, _defaultAccounts[0]);
        await _saveAccountsList(accounts);
      }
    }
  }

  /// Get all registered user accounts
  static List<UserAccount> getAccounts() {
    final raw = SessionStorage.getItem(_accountsListKey);
    if (raw == null || raw.trim().isEmpty) {
      return List.from(_defaultAccounts);
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((item) => UserAccount.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[AuthStorage] Error decoding user accounts list: $e');
      return List.from(_defaultAccounts);
    }
  }

  static Future<void> _saveAccountsList(List<UserAccount> list) async {
    final encoded = jsonEncode(list.map((a) => a.toJson()).toList());
    await SessionStorage.setItem(_accountsListKey, encoded);
  }

  /// Find account by username
  static UserAccount? findAccount(String username) {
    final accounts = getAccounts();
    final clean = username.trim().toLowerCase();
    for (final acc in accounts) {
      if (acc.username.trim().toLowerCase() == clean) {
        return acc;
      }
    }
    return null;
  }

  /// Authenticates username and password against local accounts and remote KV
  static Future<({bool success, String message, UserAccount? user})> authenticateUser({
    required String username,
    required String password,
  }) async {
    await ensureSeeded();
    final cleanUsername = username.trim();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      return (success: false, message: 'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.', user: null);
    }

    final account = findAccount(cleanUsername);
    if (account == null) {
      return (success: false, message: 'Tài khoản không tồn tại trên hệ thống.', user: null);
    }

    if (account.isLocked) {
      return (success: false, message: 'Tài khoản này đã bị khóa. Vui lòng liên hệ Admin.', user: null);
    }

    // Check remote cloud password first if available
    final remotePassword = await AuthCloudService.fetchRemotePassword(username: cleanUsername);
    final effectivePassword = (remotePassword != null && remotePassword.isNotEmpty)
        ? remotePassword
        : account.password;

    if (effectivePassword != cleanPassword && account.password != cleanPassword) {
      return (success: false, message: 'Mật khẩu không chính xác.', user: null);
    }

    // Save active session role
    await SessionStorage.setItem(_activeSessionRoleKey, account.role.toString());
    await saveActiveSessionPassword(cleanPassword);

    return (success: true, message: 'Đăng nhập thành công.', user: account);
  }

  /// Saves or updates a user account (Create / Edit)
  static Future<({bool success, String message})> saveAccount(UserAccount account) async {
    final accounts = getAccounts();
    final index = accounts.indexWhere(
      (a) => a.username.trim().toLowerCase() == account.username.trim().toLowerCase(),
    );

    if (index >= 0) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }

    await _saveAccountsList(accounts);

    // Sync with Cloudflare KV if username matches default endpoints
    AuthCloudService.pushRemotePassword(
      username: account.username,
      oldPassword: account.password,
      newPassword: account.password,
    );

    return (success: true, message: 'Đã lưu thông tin tài khoản thành công.');
  }

  /// Deletes a user account by username
  static Future<({bool success, String message})> deleteAccount(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean == defaultAdminUsername) {
      return (success: false, message: 'Không thể xóa tài khoản Admin mặc định.');
    }

    final accounts = getAccounts();
    accounts.removeWhere((a) => a.username.trim().toLowerCase() == clean);
    await _saveAccountsList(accounts);
    return (success: true, message: 'Đã xóa tài khoản thành công.');
  }

  /// Toggles active / locked status of a user account
  static Future<({bool success, String message, bool isLocked})> toggleLockAccount(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean == defaultAdminUsername) {
      return (success: false, message: 'Không thể khóa tài khoản Admin mặc định.', isLocked: false);
    }

    final account = findAccount(username);
    if (account == null) {
      return (success: false, message: 'Không tìm thấy tài khoản.', isLocked: false);
    }

    final updated = account.copyWith(isLocked: !account.isLocked);
    await saveAccount(updated);

    final statusText = updated.isLocked ? 'đã bị khóa' : 'đã được mở khóa';
    return (success: true, message: 'Tài khoản ${updated.username} $statusText.', isLocked: updated.isLocked);
  }

  /// Gets current logged-in user role (0: Admin, 1: Control, 2: Viewer)
  static int getCurrentUserRole(String username) {
    final account = findAccount(username);
    if (account != null) {
      return account.role;
    }
    if (username.trim().toLowerCase() == defaultAdminUsername) return 0;
    return 1; // Default to operator
  }

  // ─── Legacy compatibility helpers ───
  static Future<String> getPasswordForLogin() async {
    final remotePassword = await AuthCloudService.fetchRemotePassword(username: defaultUsername);
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

  static Future<void> saveActiveSessionPassword(String password) async {
    await SessionStorage.setItem(_activeSessionPasswordKey, password);
    await SessionStorage.setItem(_passwordKey, password);
  }

  static Future<String> getPassword() => getPasswordForLogin();

  static String getPasswordSync() {
    final stored = SessionStorage.getItem(_passwordKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return defaultPassword;
  }

  static Future<bool> isSessionValid() async {
    final activePassword = SessionStorage.getItem(_activeSessionPasswordKey) ??
        SessionStorage.getItem(_passwordKey) ??
        defaultPassword;

    final remotePassword = await AuthCloudService.fetchRemotePassword(username: defaultUsername);
    if (remotePassword != null && remotePassword.isNotEmpty) {
      if (remotePassword != activePassword) {
        return false;
      }
    }
    return true;
  }

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
      
      final account = findAccount(defaultUsername);
      if (account != null) {
        await saveAccount(account.copyWith(password: newPassword));
      }
    }
    return result;
  }
}
