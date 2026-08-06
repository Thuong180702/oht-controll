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
    final current = AppConstants.currentVersion.trim().split('+').first.replaceAll(RegExp(r'^v'), '');
    final latest = latestVersion.trim().split('+').first.replaceAll(RegExp(r'^v'), '');
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

  static const List<String> _versionEndpoints = [
    'https://robot-controller-remote.pages.dev/version.json',
    'https://robot-controller-remote.pages.dev/api/version',
    'https://raw.githubusercontent.com/${AppConstants.githubRepo}/main/web/version.json',
    'https://api.github.com/repos/${AppConstants.githubRepo}/releases/latest',
  ];

  /// Check for updates across version endpoints
  static Future<AppVersionInfo?> checkForUpdates() async {
    for (final endpoint in _versionEndpoints) {
      try {
        final response = await http.get(
          Uri.parse(endpoint),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'OHTControlApp/${AppConstants.currentVersion}',
          },
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final parsed = _parseVersionResponse(data, endpoint);
          if (parsed != null) return parsed;
        }
      } catch (e) {
        debugPrint('[AppUpdateService] Notice checking $endpoint: $e');
      }
    }
    return null;
  }

  static AppVersionInfo? _parseVersionResponse(Map<String, dynamic> json, String endpoint) {
    // 1. Direct version.json schema
    if (json.containsKey('version')) {
      final ver = (json['version'] as String? ?? '1.0.0').replaceAll('v', '');
      final buildNum = (json['build_number'] as num?)?.toInt() ?? 1;
      final notes = json['release_notes'] as String? ?? 'Cập nhật phiên bản mới';
      final publishedStr = json['published_at'] as String?;
      final publishedAt = publishedStr != null ? DateTime.tryParse(publishedStr) : null;

      final urlsMap = _mapFrom(json['download_urls']);
      final downloadUrls = <String, String>{};
      urlsMap.forEach((k, v) {
        downloadUrls[k.toString()] = v.toString();
      });

      downloadUrls.putIfAbsent('html', () => 'https://robot-controller-remote.pages.dev');
      downloadUrls.putIfAbsent('windows', () => downloadUrls['html']!);
      downloadUrls.putIfAbsent('android', () => downloadUrls['html']!);
      downloadUrls.putIfAbsent('macOS', () => downloadUrls['html']!);
      downloadUrls.putIfAbsent('linux', () => downloadUrls['html']!);
      downloadUrls.putIfAbsent('ios', () => downloadUrls['html']!);

      return AppVersionInfo(
        latestVersion: ver,
        buildNumber: buildNum,
        releaseNotes: notes,
        downloadUrls: downloadUrls,
        publishedAt: publishedAt,
      );
    }

    // 2. GitHub Releases API schema
    if (json.containsKey('tag_name')) {
      final tagName = (json['tag_name'] as String? ?? 'v1.0.0').replaceAll('v', '');
      final body = json['body'] as String? ?? 'Cập nhật tính năng và sửa lỗi hệ thống';
      final publishedAtStr = json['published_at'] as String?;
      final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

      final downloadUrls = <String, String>{};
      final assets = json['assets'] as List<dynamic>? ?? [];

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

      final htmlUrl = json['html_url'] as String? ?? 'https://github.com/${AppConstants.githubRepo}/releases';
      downloadUrls.putIfAbsent('html', () => htmlUrl);
      downloadUrls.putIfAbsent('windows', () => htmlUrl);
      downloadUrls.putIfAbsent('android', () => htmlUrl);
      downloadUrls.putIfAbsent('macOS', () => htmlUrl);
      downloadUrls.putIfAbsent('linux', () => htmlUrl);
      downloadUrls.putIfAbsent('ios', () => htmlUrl);

      return AppVersionInfo(
        latestVersion: tagName,
        buildNumber: 1,
        releaseNotes: body,
        downloadUrls: downloadUrls,
        publishedAt: publishedAt,
      );
    }

    return null;
  }

  static Map<String, dynamic> _mapFrom(dynamic val) {
    if (val is Map<String, dynamic>) return val;
    if (val is Map) return Map<String, dynamic>.from(val);
    return const {};
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
