import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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

  /// Launch external browser or download manager for update URL
  static Future<bool> openDownloadUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[AppUpdateService] Error launching download URL: $e');
    }
    return false;
  }

  /// Resolve direct binary download URL from GitHub Release Assets API if needed
  static Future<String> resolveDirectBinaryUrl(String originalUrl, TargetPlatform platform) async {
    if (!originalUrl.contains('github.com') || (!originalUrl.contains('/releases/latest') && !originalUrl.contains('/releases/tag/'))) {
      return originalUrl;
    }

    try {
      final repo = AppConstants.githubRepo;
      final apiUrl = 'https://api.github.com/repos/$repo/releases/latest';
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'OHTControlApp/${AppConstants.currentVersion}',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final assets = data['assets'] as List<dynamic>? ?? [];

        for (final item in assets) {
          if (item is Map<String, dynamic>) {
            final name = (item['name'] as String? ?? '').toLowerCase();
            final downloadUrl = item['browser_download_url'] as String? ?? '';
            if (downloadUrl.isNotEmpty) {
              if (platform == TargetPlatform.windows && (name.endsWith('.zip') || name.endsWith('.exe') || name.endsWith('.msi'))) {
                return downloadUrl;
              }
              if (platform == TargetPlatform.android && name.endsWith('.apk')) {
                return downloadUrl;
              }
              if (platform == TargetPlatform.macOS && (name.endsWith('.dmg') || name.endsWith('.zip') || name.endsWith('.pkg'))) {
                return downloadUrl;
              }
              if (platform == TargetPlatform.linux && (name.endsWith('.appimage') || name.endsWith('.tar.gz') || name.endsWith('.deb'))) {
                return downloadUrl;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error resolving GitHub API release assets: $e');
    }
    return originalUrl;
  }

  /// Downloads update file directly with progress callback
  static Future<File?> downloadInstallerFile({
    required String downloadUrl,
    required void Function(double progress, String bytesText) onProgress,
  }) async {
    if (kIsWeb) return null;
    try {
      // Step 1: Resolve direct binary URL via GitHub API if original URL is HTML release page
      final resolvedUrl = await resolveDirectBinaryUrl(downloadUrl, defaultTargetPlatform);
      debugPrint('[AppUpdateService] Target download URL: $resolvedUrl');

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(resolvedUrl));
      request.headers['User-Agent'] = 'OHTControlApp/${AppConstants.currentVersion}';
      final response = await client.send(request);

      if (response.statusCode != 200) {
        debugPrint('[AppUpdateService] HTTP download failed with code ${response.statusCode}');
        return null;
      }

      final contentType = (response.headers['content-type'] ?? '').toLowerCase();
      if (contentType.contains('html') || contentType.contains('text/plain')) {
        debugPrint('[AppUpdateService] Rejected download: Content-Type is $contentType (HTML/Text web page)');
        return null;
      }

      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;

      final tempDir = Directory.systemTemp;
      var rawFileName = resolvedUrl.split('/').last.split('?').first;
      if (rawFileName.isEmpty || !rawFileName.contains('.')) {
        if (Platform.isWindows) {
          rawFileName = 'oht_update.exe';
        } else if (Platform.isAndroid) {
          rawFileName = 'oht_update.apk';
        } else if (Platform.isMacOS) {
          rawFileName = 'oht_update.dmg';
        } else if (Platform.isLinux) {
          rawFileName = 'oht_update.AppImage';
        } else {
          rawFileName = 'oht_update.bin';
        }
      }
      final saveFile = File('${tempDir.path}${Platform.pathSeparator}$rawFileName');
      if (await saveFile.exists()) {
        try {
          await saveFile.delete();
        } catch (_) {}
      }

      final sink = saveFile.openWrite();

      await for (final chunk in response.stream) {
        downloadedBytes += chunk.length;
        sink.add(chunk);
        if (totalBytes > 0) {
          final progress = downloadedBytes / totalBytes;
          final downloadedMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
          final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
          onProgress(progress, '$downloadedMb MB / $totalMb MB');
        } else {
          final downloadedMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
          onProgress(0.5, '$downloadedMb MB');
        }
      }

      await sink.flush();
      await sink.close();

      // Check binary header to ensure it is a valid binary payload, not an HTML web page
      if (await saveFile.exists()) {
        final length = await saveFile.length();
        if (length < 1000) {
          debugPrint('[AppUpdateService] Downloaded file is too small ($length bytes), likely HTML or redirect page.');
          await saveFile.delete();
          return null;
        }

        final sampleBytes = await saveFile.openRead(0, 512).first;
        final sampleText = String.fromCharCodes(sampleBytes).toLowerCase();

        if (sampleText.contains('<!doctype') ||
            sampleText.contains('<html') ||
            sampleText.contains('<body') ||
            sampleText.contains('<head') ||
            sampleText.contains('{"message"') ||
            sampleBytes.first == 0x3C) {
          debugPrint('[AppUpdateService] Downloaded payload contains HTML/Text metadata, not binary package.');
          await saveFile.delete();
          return null;
        }
      }

      return saveFile;
    } catch (e) {
      debugPrint('[AppUpdateService] Error downloading update file: $e');
    }
    return null;
  }

  /// Launch installer file or execute self-updater script across Windows, Android, macOS, Linux
  static Future<bool> launchInstaller(File file) async {
    if (kIsWeb) return false;
    try {
      final path = file.path;

      if (Platform.isWindows) {
        final currentExePath = Platform.resolvedExecutable;
        final exeName = currentExePath.split(Platform.pathSeparator).last;
        final currentAppDir = Directory(currentExePath).parent.path;
        final batFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}oht_updater.bat');

        if (path.toLowerCase().endsWith('.zip')) {
          final batContent = '''
@echo off
setlocal enabledelayedexpansion

:wait_loop
tasklist /FI "IMAGENAME eq $exeName" 2>NUL | find /I "$exeName" >NUL
if "%ERRORLEVEL%"=="0" (
    timeout /t 1 /nobreak >NUL
    goto wait_loop
)

timeout /t 1 /nobreak >NUL

powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '$path' -DestinationPath '$currentAppDir' -Force"

start "" "$currentExePath"
del "%~f0"
''';
          await batFile.writeAsString(batContent);
          await Process.start('cmd.exe', ['/c', batFile.path], runInShell: true);
          exit(0);
        } else if (path.toLowerCase().endsWith('.exe') || path.toLowerCase().endsWith('.msi')) {
          final batContent = '''
@echo off
:wait_loop
tasklist /FI "IMAGENAME eq $exeName" 2>NUL | find /I "$exeName" >NUL
if "%ERRORLEVEL%"=="0" (
    timeout /t 1 /nobreak >NUL
    goto wait_loop
)

timeout /t 1 /nobreak >NUL
start "" "$path"
del "%~f0"
''';
          await batFile.writeAsString(batContent);
          await Process.start('cmd.exe', ['/c', batFile.path], runInShell: true);
          exit(0);
        } else {
          await Process.run('explorer.exe', ['/select,', path]);
          return true;
        }
      } else if (Platform.isAndroid) {
        // Trigger Android Package Installer via system file handler
        final uri = Uri.file(path);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return await openDownloadUrl(path);
      } else if (Platform.isMacOS) {
        // Open DMG image or PKG installer
        if (path.endsWith('.dmg')) {
          await Process.start('hdiutil', ['attach', path], runInShell: true);
          await Process.start('open', [path], runInShell: true);
        } else {
          await Process.start('open', [path], runInShell: true);
        }
        return true;
      } else if (Platform.isLinux) {
        // Make AppImage executable and launch
        if (path.endsWith('.AppImage')) {
          await Process.run('chmod', ['+x', path]);
          await Process.start(path, [], runInShell: true);
          exit(0);
        } else {
          await Process.start('xdg-open', [path], runInShell: true);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error launching installer: $e');
    }
    return false;
  }
}
