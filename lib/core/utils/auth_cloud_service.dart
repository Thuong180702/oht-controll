import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_account.dart';

class AuthCloudService {
  AuthCloudService._();

  static const String _defaultEndpoint =
      'https://robot-controller-remote.pages.dev/api/auth/password';

  /// Synchronize password for a single user from Cloudflare KV.
  static Future<String?> fetchRemotePassword({String username = 'Thaco'}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse('$_defaultEndpoint?username=$username&_t=$timestamp');
      final response = await http
          .get(
            uri,
            headers: {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['password'] != null) {
          final remotePassword = data['password'] as String;
          if (remotePassword.isNotEmpty) {
            return remotePassword;
          }
        }
      }
    } catch (e) {
      debugPrint('[AuthCloudService] Remote fetch offline/notice: $e');
    }
    return null;
  }

  /// Push updated password to Cloudflare KV.
  /// If [force] is true (e.g. Admin creation/edit), oldPassword check is bypassed.
  static Future<({bool success, String message})> pushRemotePassword({
    required String username,
    String? oldPassword,
    required String newPassword,
    bool force = false,
  }) async {
    try {
      final uri = Uri.parse(_defaultEndpoint);
      final payload = jsonEncode({
        'username': username,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'force': force,
      });

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(seconds: 4));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return (
          success: true,
          message: 'Thay đổi mật khẩu thành công.',
        );
      } else {
        final msg = data['message'] as String? ?? 'Không thể đổi mật khẩu.';
        if (msg.contains('Old password')) {
          return (success: false, message: 'Mật khẩu cũ không chính xác.');
        }
        return (success: false, message: msg);
      }
    } catch (e) {
      debugPrint('[AuthCloudService] Remote push error: $e');
      return (
        success: false,
        message: 'Vui lòng kiểm tra kết nối mạng để thay đổi mật khẩu.',
      );
    }
  }

  /// Delete user key from Cloudflare KV when an account is deleted by Admin
  static Future<void> deleteRemoteAccount(String username) async {
    try {
      final uri = Uri.parse('$_defaultEndpoint?username=$username');
      await http.delete(uri).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[AuthCloudService] Delete remote account error: $e');
    }
  }

  /// Push complete user accounts list to Cloudflare KV for cross-device sync
  static Future<void> pushAccountsList(List<UserAccount> accounts) async {
    try {
      final uri = Uri.parse('$_defaultEndpoint?action=accounts');
      final payload = jsonEncode({
        'accountsList': accounts.map((a) => a.toJson()).toList(),
      });
      await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[AuthCloudService] Push accounts list error: $e');
    }
  }

  /// Fetch lock + role status for a specific user from Cloudflare KV accounts list.
  /// Returns null if offline or user not found.
  static Future<({bool isLocked, int role})?> fetchRemoteAccountStatus(String username) async {
    try {
      final accounts = await fetchAccountsList();
      if (accounts == null) return null;
      final clean = username.trim().toLowerCase();
      for (final acc in accounts) {
        if (acc.username.trim().toLowerCase() == clean) {
          return (isLocked: acc.isLocked, role: acc.role);
        }
      }
    } catch (e) {
      debugPrint('[AuthCloudService] Fetch account status error: $e');
    }
    return null;
  }

  /// Fetch complete user accounts list from Cloudflare KV
  static Future<List<UserAccount>?> fetchAccountsList() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse('$_defaultEndpoint?action=accounts&_t=$timestamp');
      final response = await http
          .get(
            uri,
            headers: {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['accounts'] != null) {
          final List<dynamic> list = data['accounts'];
          return list.map((item) => UserAccount.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('[AuthCloudService] Fetch accounts list error: $e');
    }
    return null;
  }
}
