import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_account.dart';
import 'auth_cloud_service.dart';
import 'app_preferences.dart';
import 'session_storage.dart';

class AuthStorage {
  static const defaultUsername = 'Thaco';
  static const defaultPassword = 'Thaco@1234';
  
  static const defaultAdminUsername = 'Thaco';
  static const defaultAdminPassword = 'Thaco@1234';

  static const _accountsListKey = 'oht_user_accounts_v3';
  static const _passwordKey = 'admin_password';
  static const _activeSessionPasswordKey = 'active_session_password';
  static const _activeSessionRoleKey = 'active_session_role';

  /// Pre-seeded default user accounts with Thaco as Admin (Role 0)
  static final List<UserAccount> _defaultAccounts = [
    UserAccount(
      username: defaultUsername,
      password: defaultPassword,
      role: 0, // Admin (Quản trị viên)
      isLocked: false,
      createdAt: '2026-01-01T00:00:00.000Z',
    ),
  ];

  /// Ensures default accounts exist and syncs background session
  static Future<void> ensureSeeded() async {
    final accounts = getAccounts();
    
    // Remove old 'admin' account if present
    accounts.removeWhere((a) => a.username.trim().toLowerCase() == 'admin');

    final thacoIndex = accounts.indexWhere((a) => a.username.trim().toLowerCase() == 'thaco');
    if (thacoIndex >= 0) {
      // Ensure Thaco has Role 0 (Admin)
      accounts[thacoIndex] = accounts[thacoIndex].copyWith(role: 0);
    } else {
      accounts.insert(0, _defaultAccounts[0]);
    }
    await _saveAccountsList(accounts);

    // Background sync accounts list from Cloudflare KV
    final remoteAccounts = await AuthCloudService.fetchAccountsList();
    if (remoteAccounts != null && remoteAccounts.isNotEmpty) {
      remoteAccounts.removeWhere((a) => a.username.trim().toLowerCase() == 'admin');
      final rIndex = remoteAccounts.indexWhere((a) => a.username.trim().toLowerCase() == 'thaco');
      if (rIndex >= 0) {
        remoteAccounts[rIndex] = remoteAccounts[rIndex].copyWith(role: 0);
      } else {
        remoteAccounts.insert(0, _defaultAccounts[0]);
      }
      await _saveAccountsList(remoteAccounts);
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
      final list = decoded.map((item) => UserAccount.fromJson(item as Map<String, dynamic>)).toList();
      list.removeWhere((a) => a.username.trim().toLowerCase() == 'admin');
      return list.isEmpty ? List.from(_defaultAccounts) : list;
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

    // Sync individual password & full accounts list with Cloudflare KV
    AuthCloudService.pushRemotePassword(
      username: account.username,
      newPassword: account.password,
      force: true,
    );
    AuthCloudService.pushAccountsList(accounts);

    return (success: true, message: 'Đã lưu thông tin tài khoản thành công.');
  }

  /// Deletes a user account by username
  static Future<({bool success, String message})> deleteAccount(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean == 'thaco') {
      return (success: false, message: 'Không thể xóa tài khoản Thaco (Admin mặc định).');
    }

    final accounts = getAccounts();
    accounts.removeWhere((a) => a.username.trim().toLowerCase() == clean);
    await _saveAccountsList(accounts);

    // Delete remote key & push updated list to Cloudflare KV
    AuthCloudService.deleteRemoteAccount(username);
    AuthCloudService.pushAccountsList(accounts);

    return (success: true, message: 'Đã xóa tài khoản thành công.');
  }

  /// Toggles active / locked status of a user account
  static Future<({bool success, String message, bool isLocked})> toggleLockAccount(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean == 'thaco') {
      return (success: false, message: 'Không thể khóa tài khoản Thaco (Admin mặc định).', isLocked: false);
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
    if (username.trim().toLowerCase() == 'thaco') return 0; // Thaco is Admin
    return 1;
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

  /// Returns false if the session should be terminated:
  /// - password was changed from another device, OR
  /// - account was locked by Admin.
  static Future<bool> isSessionValid(String username) async {
    final clean = username.trim();
    if (clean.isEmpty) return true;

    // Check isLocked first from the synced accounts list in KV
    final remoteStatus = await AuthCloudService.fetchRemoteAccountStatus(clean);
    if (remoteStatus != null && remoteStatus.isLocked) {
      return false; // Account was locked by Admin — force logout
    }

    // Also check local lock status (in case offline but account was pre-locked)
    final localAccount = findAccount(clean);
    if (localAccount != null && localAccount.isLocked) {
      return false;
    }

    final activePassword = SessionStorage.getItem(_activeSessionPasswordKey);
    if (activePassword == null || activePassword.isEmpty) return true;

    final remotePassword = await AuthCloudService.fetchRemotePassword(username: clean);
    if (remotePassword != null && remotePassword.isNotEmpty) {
      if (remotePassword != activePassword) {
        return false; // Password changed from another device
      }
    }
    return true;
  }

  static Future<({bool success, String message})> changePassword({
    required String oldPassword,
    required String newPassword,
    String? username,
  }) async {
    final targetUser = (username != null && username.trim().isNotEmpty)
        ? username.trim()
        : (AppPreferences.getLoggedInUser() ?? defaultUsername);

    final result = await AuthCloudService.pushRemotePassword(
      username: targetUser,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );

    if (result.success) {
      await SessionStorage.setItem(_passwordKey, newPassword);
      await SessionStorage.setItem(_activeSessionPasswordKey, newPassword);
      
      final account = findAccount(targetUser);
      if (account != null) {
        await saveAccount(account.copyWith(password: newPassword));
      }
    }
    return result;
  }
}
