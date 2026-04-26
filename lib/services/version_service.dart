import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class VersionInfo {
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final bool isUpdateAvailable;

  VersionInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.isUpdateAvailable,
  });
}

class VersionService {
  static const String _owner = 'greeeeggy';
  static const String _repo = 'aeternum';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  Future<VersionInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
      debugPrint('[VersionService] Checking for updates. Current version: $currentVersion');

      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 10));
      debugPrint('[VersionService] GitHub API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String latestVersion =
            data['tag_name'].toString().replaceAll('v', '');
        debugPrint('[VersionService] Latest version found on GitHub: $latestVersion');

        final String releaseNotes = data['body'] ?? '';

        // Find the first APK asset
        String? downloadUrl;
        final assets = data['assets'] as List;
        for (var asset in assets) {
          if (asset['name'].toString().endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'];
            break;
          }
        }

        // If no APK found, use the release page as fallback
        downloadUrl ??= data['html_url'];

        final isAvailable = _isVersionGreater(latestVersion, currentVersion);
        debugPrint('[VersionService] Update available: $isAvailable');

        return VersionInfo(
          latestVersion: latestVersion,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl!,
          isUpdateAvailable: isAvailable,
        );
      }
    } catch (e) {
      debugPrint('[VersionService] Error checking for updates: $e');
    }
    return null;
  }

  bool _isVersionGreater(String latest, String current) {
    try {
      // Normalize versions by replacing '+' with '.' to handle build numbers
      List<int> latestParts =
          latest.replaceAll('+', '.').split('.').map(int.parse).toList();
      List<int> currentParts =
          current.replaceAll('+', '.').split('.').map(int.parse).toList();

      int length = latestParts.length > currentParts.length
          ? latestParts.length
          : currentParts.length;

      for (int i = 0; i < length; i++) {
        int l = i < latestParts.length ? latestParts[i] : 0;
        int c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (e) {
      return latest != current;
    }
  }
}
