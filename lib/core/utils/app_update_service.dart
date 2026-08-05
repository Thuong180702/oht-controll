import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

class AppVersionInfo {
  const AppVersionInfo({
    required this.latestVersion,
    required this.buildNumber,
    required this.releaseNotes,
    required this.downloadUrls,
    this.publishedAt,
    this.isMandatory = false,
  });

  final String latestVersion;
  final int buildNumber;
  final String releaseNotes;
  final Map<String, String> downloadUrls;
  final DateTime? publishedAt;
  final bool isMandatory;

  bool get isUpdateAvailable {
    final current = AppConstants.currentVersion.trim();
    final latest = latestVersion.trim().replaceAll(RegExp(r'^v'), '');
    return _compareVersions(latest, current) > 0;
  }

  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;

    for (var i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }
}

class AppUpdateService {
  AppUpdateService._();

  static const String _githubApiUrl =
      'https://api.github.com/repos/${AppConstants.githubRepo}/releases/latest';

  /// Check for updates from GitHub Releases API
  static Future<AppVersionInfo?> checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String? ?? 'v1.0.0').replaceAll('v', '');
        final body = data['body'] as String? ?? 'Cập nhật tính năng và sửa lỗi hệ thống';
        final publishedAtStr = data['published_at'] as String?;
        final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

        final downloadUrls = <String, String>{};
        final assets = data['assets'] as List<dynamic>? ?? [];

        for (final asset in assets) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          final downloadUrl = asset['browser_download_url'] as String? ?? '';
          if (downloadUrl.isEmpty) continue;

          if (name.endsWith('.apk')) {
            downloadUrls['android'] = downloadUrl;
          } else if (name.endsWith('.exe') || name.endsWith('.msi') || (name.contains('windows') && name.endsWith('.zip'))) {
            downloadUrls['windows'] = downloadUrl;
          } else if (name.endsWith('.dmg') || (name.contains('mac') && name.endsWith('.zip'))) {
            downloadUrls['macOS'] = downloadUrl;
          } else if (name.endsWith('.tar.gz') || name.endsWith('.appimage') || (name.contains('linux') && name.endsWith('.zip'))) {
            downloadUrls['linux'] = downloadUrl;
          }
        }

        // Default GitHub Release HTML URL if platform-specific asset is not found
        final htmlUrl = data['html_url'] as String? ?? 'https://github.com/${AppConstants.githubRepo}/releases';
        downloadUrls.putIfAbsent('html', () => htmlUrl);
        downloadUrls.putIfAbsent('ios', () => htmlUrl);

        return AppVersionInfo(
          latestVersion: tagName,
          buildNumber: 1,
          releaseNotes: body,
          downloadUrls: downloadUrls,
          publishedAt: publishedAt,
        );
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking GitHub releases: $e');
    }
    return null;
  }

  /// Get download URL for specific platform
  static String getDownloadUrl(AppVersionInfo info, TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
        return info.downloadUrls['android'] ?? info.downloadUrls['html']!;
      case TargetPlatform.windows:
        return info.downloadUrls['windows'] ?? info.downloadUrls['html']!;
      case TargetPlatform.macOS:
        return info.downloadUrls['macOS'] ?? info.downloadUrls['html']!;
      case TargetPlatform.linux:
        return info.downloadUrls['linux'] ?? info.downloadUrls['html']!;
      case TargetPlatform.iOS:
        return info.downloadUrls['ios'] ?? info.downloadUrls['html']!;
      case TargetPlatform.fuchsia:
        return info.downloadUrls['html']!;
    }
  }
}
