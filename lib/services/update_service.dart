import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;

  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

/// Service to check for new releases on GitHub and trigger direct APK updates
class UpdateService {
  /// Current app version
  static const String currentVersion = '1.2.0';

  /// GitHub public releases endpoint
  static const String latestReleaseApi =
      'https://api.github.com/repos/Aman6390/imd-portal/releases/latest';

  /// Queries GitHub Releases API to see if a newer version is available
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(latestReleaseApi),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'IMD-Portal-App/$currentVersion',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = (data['tag_name'] as String? ?? '').trim();
        final rawVersion = tagName.replaceAll(RegExp(r'[^0-9.]'), '');
        final body = (data['body'] as String? ?? '').trim();
        final htmlUrl =
            (data['html_url'] as String? ?? 'https://github.com/Aman6390/imd-portal/releases')
                .trim();

        // Search for direct APK asset download URL
        String apkDownloadUrl = htmlUrl;
        if (data['assets'] is List) {
          for (final asset in data['assets']) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.apk')) {
              apkDownloadUrl = (asset['browser_download_url'] as String? ?? apkDownloadUrl).trim();
              break;
            }
          }
        }

        final isNewer = _isVersionGreater(rawVersion, currentVersion);
        return UpdateInfo(
          hasUpdate: isNewer,
          latestVersion: tagName.isNotEmpty ? tagName : 'v$rawVersion',
          downloadUrl: apkDownloadUrl,
          releaseNotes: body,
        );
      }
    } catch (_) {
      // Fail silently if offline or on network error
    }
    return null;
  }

  /// Compares semantic versions e.g. "1.3.0" > "1.2.0"
  static bool _isVersionGreater(String latest, String current) {
    try {
      final latestParts = latest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final currentParts = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (_) {
      return false;
    }
  }

  /// Opens the APK download link in external browser or package installer
  static Future<void> downloadAndInstall(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Shows the Update dialog to the user
  static void showUpdateDialog(BuildContext context, UpdateInfo update) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update_alt, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(
              'Update Available (${update.latestVersion})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A newer version of IMD Portal is available! Update now to receive the latest features, circular updates, and fixes.',
              style: TextStyle(fontSize: 13),
            ),
            if (update.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'What\'s New:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    update.releaseNotes,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Update Now'),
            onPressed: () {
              Navigator.of(ctx).pop();
              downloadAndInstall(update.downloadUrl);
            },
          ),
        ],
      ),
    );
  }
}
