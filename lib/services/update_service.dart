import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'notification_service.dart';

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

class UpdateDownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double progress; // 0.0 to 1.0
  final bool isCompleted;
  final String? filePath;
  final String? error;

  const UpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.progress,
    this.isCompleted = false,
    this.filePath,
    this.error,
  });
}

/// Service to check for new releases on GitHub, display urgent update alerts,
/// and manage background APK downloading without interrupting user experience.
class UpdateService {
  /// Current app version
  static const String currentVersion = '1.4.15';

  /// GitHub public releases endpoint
  static const String latestReleaseApi =
      'https://api.github.com/repos/Aman6390/imd-portal/releases/latest';

  // Broadcast stream for background download progress
  static final StreamController<UpdateDownloadProgress> _progressController =
      StreamController<UpdateDownloadProgress>.broadcast();

  static Stream<UpdateDownloadProgress> get progressStream =>
      _progressController.stream;

  static bool isDownloading = false;

  /// Queries GitHub Releases API to see if a newer version is available
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(latestReleaseApi),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Meteorological-Portal-App/$currentVersion',
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
              apkDownloadUrl =
                  (asset['browser_download_url'] as String? ?? apkDownloadUrl).trim();
              break;
            }
          }
        }

        final isNewer = _isVersionGreater(rawVersion, currentVersion);
        if (isNewer) {
          NotificationService.showUpdateAvailableNotification(
            version: rawVersion,
            downloadUrl: apkDownloadUrl,
          );
        }
        return UpdateInfo(
          hasUpdate: isNewer,
          latestVersion: tagName.isNotEmpty ? tagName : 'v$rawVersion',
          downloadUrl: apkDownloadUrl,
          releaseNotes: body,
        );
      }
    } catch (_) {
      // Fail silently on network error
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

  /// Starts downloading the APK in the background while user continues using the app
  static Future<void> startBackgroundDownload(String downloadUrl) async {
    if (isDownloading) return;
    isDownloading = true;

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'Meteorological-Portal-App/$currentVersion';
      final response = await client.send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;

        // Use external cache directory if available for maximum package installer compatibility
        Directory dir;
        try {
          final extDirs = await getExternalCacheDirectories();
          if (extDirs != null && extDirs.isNotEmpty) {
            dir = extDirs.first;
          } else {
            dir = await getTemporaryDirectory();
          }
        } catch (_) {
          dir = await getTemporaryDirectory();
        }

        // 1. Clean up old update APK files to prevent cache collisions
        try {
          final list = dir.listSync();
          for (final entity in list) {
            if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
              try { entity.deleteSync(); } catch (_) {}
            }
          }
        } catch (_) {}

        // 2. Stream downloaded bytes into clean file
        final file = File('${dir.path}/IMD_Portal_Update.apk');
        final sink = file.openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          final progress = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;
          _progressController.add(UpdateDownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            progress: progress,
          ));
        }

        await sink.flush();
        await sink.close();
        client.close();

        // 3. Verify file integrity and allow 400ms for OS filesystem buffers to settle
        if (!await file.exists() || await file.length() < 1000000) {
          throw Exception('Downloaded update is incomplete or corrupted.');
        }
        await Future.delayed(const Duration(milliseconds: 400));

        isDownloading = false;

        _progressController.add(UpdateDownloadProgress(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          progress: 1.0,
          isCompleted: true,
          filePath: file.path,
        ));

        // Show Android system notification with 1-tap install action
        await NotificationService.showUpdateDownloadedNotification(
          filePath: file.path,
        );

        // Automatically trigger native package installer with downloaded APK file
        await installDownloadedApk(file.path);
      } else {
        isDownloading = false;
        _progressController.add(UpdateDownloadProgress(
          receivedBytes: 0,
          totalBytes: 0,
          progress: 0.0,
          error: 'Download server returned HTTP ${response.statusCode}',
        ));
      }
    } catch (e) {
      isDownloading = false;
      _progressController.add(UpdateDownloadProgress(
        receivedBytes: 0,
        totalBytes: 0,
        progress: 0.0,
        error: e.toString(),
      ));
    }
  }

  static const MethodChannel _installerChannel = MethodChannel('com.imd.portal/installer');

  /// Installs the downloaded APK file via native Android package installer.
  /// Returns 'SUCCESS', 'PERMISSION_REQUESTED', 'FILE_NOT_FOUND', or an error description.
  static Future<String> installDownloadedApk(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return 'FILE_NOT_FOUND';
      }
      final String? response = await _installerChannel.invokeMethod<String>(
        'installApk',
        {'apkPath': filePath},
      );
      return response ?? 'UNKNOWN';
    } catch (e) {
      print('Native APK installation error: $e');
      return 'ERROR: $e';
    }
  }

  /// Opens APK via system download/installer
  static Future<void> launchExternalApk(String url) async {
    try {
      final cleanUrl = Uri.encodeFull(url.trim());
      final uri = Uri.parse(cleanUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }

  /// Displays an urgent, high-conversion update dialog using proven psychological triggers
  static void showUrgentUpdateDialog(
    BuildContext context,
    UpdateInfo update, {
    required VoidCallback onStartBackgroundDownload,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents tapping outside to force attention
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Critical Update Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Urgency Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Meteorological Portal ${update.latestVersion} Available',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Urgency Body (Fear of sync failure & missing circulars)
            const Text(
              '⚠️ Important Notice: An essential portal update is required to ensure synchronization with MetNet intranet protocols.\n\n'
              'Older versions may encounter login authentication failures, inaccurate leave balance predictions, or miss critical departmental orders.\n\n'
              'The update downloads silently in the background while you continue using the app.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            if (update.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'What\'s New in this Release:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 90),
                child: SingleChildScrollView(
                  child: Text(
                    update.releaseNotes,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Dismissive button de-emphasized
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Remind Me Next Time',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          // High-conversion primary call to action
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Update Now (Background)'),
            onPressed: () {
              Navigator.of(ctx).pop();
              onStartBackgroundDownload();
            },
          ),
        ],
      ),
    );
  }

  /// Backward compatible helper
  static void showUpdateDialog(BuildContext context, UpdateInfo update) {
    showUrgentUpdateDialog(
      context,
      update,
      onStartBackgroundDownload: () {
        startBackgroundDownload(update.downloadUrl);
      },
    );
  }
}
