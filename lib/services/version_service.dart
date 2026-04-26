import 'dart:convert';
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
  final String _apiUrl = 'https://api.github.com/repos/greeeeggy/aeternum/releases/latest';

  Future<VersionInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String latestVersion = data['tag_name'].toString().replaceAll('v', '');
        
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

        return VersionInfo(
          latestVersion: latestVersion,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl!,
          isUpdateAvailable: isAvailable,
        );
      }
    } catch (e) {
      print('[VersionService] Error: $e');
    }
    return null;
  }

  bool _isVersionGreater(String latest, String current) {
    try {
      List<int> latestParts = latest.split('.').map(int.parse).toList();
      List<int> currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      return latest != current;
    }
  }
}
