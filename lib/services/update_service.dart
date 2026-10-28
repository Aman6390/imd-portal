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
  static const String currentVersion = '1.4.24';

  /// GitHub public releases endpoint
  static const List<String> releaseApiEndpoints = [
    'https://api.github.com/repos/Aman6390/metnet-circulars-index/releases/latest',
    'https://api.github.com/repos/Aman6390/imd-portal/releases/latest',
  ];
  static const String latestReleaseApi =
      'https://api.github.com/repos/Aman6390/metnet-circulars-index/releases/latest';

  // Broadcast stream for background download progress
  static final StreamController<UpdateDownloadProgress> _progressController =
      StreamController<UpdateDownloadProgress>.broadcast();

  static Stream<UpdateDownloadProgress> get progressStream =>
      _progressController.stream;

  static bool isDownloading = false;

  /// Returns the optimal storage directory for update APKs
  static Future<Directory> getUpdateDirectory() async {
    try {
      final extDirs = await getExternalCacheDirectories();
      if (extDirs != null && extDirs.isNotEmpty) {
        return extDirs.first;
      }
    } catch (_) {}
    return await getTemporaryDirectory();
  }

  /// Formats a version tag into a clean, safe filename
  static Future<File> getUpdateFileForVersion(String versionTag) async {
    final dir = await getUpdateDirectory();
    final sanitizedVersion = versionTag
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final filename = sanitizedVersion.isNotEmpty
        ? 'IMD_Portal_Update_$sanitizedVersion.apk'
        : 'IMD_Portal_Update.apk';
    return File('${dir.path}/$filename');
  }

  /// Checks if an APK for the target version has already been fully downloaded
  static Future<String?> getAlreadyDownloadedApkPath(String versionTag) async {
    try {
      final file = await getUpdateFileForVersion(versionTag);
      if (await file.exists()) {
        final length = await file.length();
        // A genuine IMD Portal APK is ~49MB. Any valid complete APK will exceed 5MB.
        if (length > 5000000) {
          return file.path;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Queries GitHub Releases API to see if a newer version is available
  static Future<UpdateInfo?> checkForUpdate() async {
    for (final endpoint in releaseApiEndpoints) {
      try {
        final response = await http.get(
          Uri.parse(endpoint),
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
          final htmlUrl = (data['html_url'] as String? ??
                  'https://github.com/Aman6390/metnet-circulars-index/releases')
              .trim();

          // Search for direct APK asset download URL
          String apkDownloadUrl = htmlUrl;
          if (data['assets'] is List) {
            for (final asset in data['assets']) {
              final name = (asset['name'] as String? ?? '').toLowerCase();
              if (name.endsWith('.apk')) {
                apkDownloadUrl =
                    (asset['browser_download_url'] as String? ?? apkDownloadUrl)
                        .trim();
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
        // Fall back to next endpoint if network fails
      }
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

  /// Starts downloading the APK in the background while user continues using the app.
  /// If the target version APK is already present on disk, immediately triggers installation
  /// with 0 MB data usage unless [forceRedownload] is true.
  static Future<void> startBackgroundDownload(
    String downloadUrl, {
    String versionTag = '',
    bool forceRedownload = false,
  }) async {
    if (isDownloading) return;

    // Resolve version tag if empty (extract from URL e.g. v1.4.17)
    String effectiveVersion = versionTag.trim();
    if (effectiveVersion.isEmpty) {
      final match = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(downloadUrl);
      if (match != null) {
        effectiveVersion = match.group(0) ?? '';
      }
    }

    // 1. Fast-path: Check if the APK is already fully downloaded on the device
    if (!forceRedownload && effectiveVersion.isNotEmpty) {
      final cachedPath = await getAlreadyDownloadedApkPath(effectiveVersion);
      if (cachedPath != null) {
        _progressController.add(UpdateDownloadProgress(
          receivedBytes: 100,
          totalBytes: 100,
          progress: 1.0,
          isCompleted: true,
          filePath: cachedPath,
        ));
        await NotificationService.showUpdateDownloadedNotification(
          filePath: cachedPath,
        );
        await installDownloadedApk(cachedPath);
        return;
      }
    }

    isDownloading = true;

    try {
      final targetFile = await getUpdateFileForVersion(effectiveVersion);
      final dir = targetFile.parent;

      // Clean up ONLY older or different version APKs to free storage
      try {
        final list = dir.listSync();
        for (final entity in list) {
          if (entity is File &&
              entity.path.toLowerCase().endsWith('.apk') &&
              entity.path != targetFile.path) {
            try {
              entity.deleteSync();
            } catch (_) {}
          }
        }
      } catch (_) {}

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'Meteorological-Portal-App/$currentVersion';
      final response = await client.send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;

        // Stream into temporary .part file to avoid partially-written file corruption
        final tempFile = File('${targetFile.path}.part');
        if (await tempFile.exists()) {
          try {
            tempFile.deleteSync();
          } catch (_) {}
        }
        final sink = tempFile.openWrite();

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

        // Verify file integrity (must be > 5MB)
        if (!await tempFile.exists() || await tempFile.length() < 5000000) {
          try {
            tempFile.deleteSync();
          } catch (_) {}
          throw Exception('Downloaded update is incomplete or corrupted.');
        }

        // Atomically replace targetFile
        if (await targetFile.exists()) {
          try {
            targetFile.deleteSync();
          } catch (_) {}
        }
        await tempFile.rename(targetFile.path);

        // Allow 400ms for OS filesystem buffers to settle
        await Future.delayed(const Duration(milliseconds: 400));

        isDownloading = false;

        _progressController.add(UpdateDownloadProgress(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          progress: 1.0,
          isCompleted: true,
          filePath: targetFile.path,
        ));

        // Show Android system notification with 1-tap install action
        await NotificationService.showUpdateDownloadedNotification(
          filePath: targetFile.path,
        );

        // Automatically trigger native package installer with downloaded APK file
        await installDownloadedApk(targetFile.path);
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

  /// Displays an urgent, high-conversion update dialog using proven psychological triggers.
  /// If [alreadyDownloadedPath] is provided, displays an immediate install prompt with zero network download.
  static void showUrgentUpdateDialog(
    BuildContext context,
    UpdateInfo update, {
    String? alreadyDownloadedPath,
    required VoidCallback onStartBackgroundDownload,
  }) {
    final bool isAlreadyCached =
        alreadyDownloadedPath != null && alreadyDownloadedPath.isNotEmpty;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevents tapping outside to force attention
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isAlreadyCached ? Colors.green : Colors.redAccent,
            width: 1.5,
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        title: Row(
          children: [
            Icon(
              isAlreadyCached ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: isAlreadyCached ? Colors.green : Colors.redAccent,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isAlreadyCached ? 'Update Ready to Install' : 'Critical Update Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isAlreadyCached ? Colors.green.shade800 : Colors.redAccent,
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
                color: (isAlreadyCached ? Colors.green : Colors.redAccent).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isAlreadyCached ? Icons.download_done_rounded : Icons.bolt,
                    color: isAlreadyCached ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isAlreadyCached
                        ? 'Update Downloaded (${update.latestVersion})'
                        : 'Meteorological Portal ${update.latestVersion} Available',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isAlreadyCached ? Colors.green.shade800 : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Urgency Body
            Text(
              isAlreadyCached
                  ? '✅ The update package has already been downloaded to your device.\n\n'
                    'Tap below to install it immediately — no mobile data or download time required!'
                  : '⚠️ Important Notice: An essential portal update is required to ensure synchronization with MetNet intranet protocols.\n\n'
                    'Older versions may encounter login authentication failures, inaccurate leave balance predictions, or miss critical departmental orders.\n\n'
                    'The update downloads silently in the background while you continue using the app.',
              style: const TextStyle(fontSize: 13, height: 1.4),
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
              backgroundColor: isAlreadyCached ? Colors.green.shade700 : Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            icon: Icon(
              isAlreadyCached ? Icons.system_update_rounded : Icons.download_rounded,
              size: 18,
            ),
            label: Text(isAlreadyCached ? 'Install Now (No Download)' : 'Update Now (Background)'),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (isAlreadyCached) {
                installDownloadedApk(alreadyDownloadedPath);
              } else {
                onStartBackgroundDownload();
              }
            },
          ),
        ],
      ),
    );
  }

  /// Backward compatible helper
  static void showUpdateDialog(BuildContext context, UpdateInfo update) async {
    final cached = await getAlreadyDownloadedApkPath(update.latestVersion);
    if (!context.mounted) return;
    showUrgentUpdateDialog(
      context,
      update,
      alreadyDownloadedPath: cached,
      onStartBackgroundDownload: () {
        startBackgroundDownload(
          update.downloadUrl,
          versionTag: update.latestVersion,
        );
      },
    );
  }
}
