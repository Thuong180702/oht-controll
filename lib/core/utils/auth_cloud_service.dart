import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'session_storage.dart';

class AuthCloudService {
  AuthCloudService._();

  static const String _defaultEndpoint =
      'https://robot-controller-remote.pages.dev/api/auth/password';

  /// Synchronize password from Cloudflare KV.
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
            await SessionStorage.setItem('admin_password', remotePassword);
            return remotePassword;
          }
        }
      }
    } catch (e) {
      debugPrint('[AuthCloudService] Remote fetch offline/notice: $e');
    }
    return null;
  }

  /// Push updated password to Cloudflare KV. Requires online connection.
  static Future<({bool success, String message})> pushRemotePassword({
    required String username,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final uri = Uri.parse(_defaultEndpoint);
      final payload = jsonEncode({
        'username': username,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
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
        await SessionStorage.setItem('admin_password', newPassword);
        return (
          success: true,
          message: 'Đã cập nhật và đồng bộ mật khẩu lên hệ thống.',
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
        message: 'Vui lòng kết nối mạng để đổi mật khẩu và đồng bộ hệ thống.',
      );
    }
  }
}
