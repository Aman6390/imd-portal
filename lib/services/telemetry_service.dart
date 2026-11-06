import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'update_service.dart';

/// Data model representing aggregated telemetry metrics for the Master dashboard.
class TelemetryReport {
  final int totalInstalls;
  final int activeToday;
  final int activePast7Days;
  final Map<String, int> versionDistribution;
  final int weatherBannerEnabledCount;
  final int weatherBannerDisabledCount;
  final List<TelemetryPingItem> recentPings;

  TelemetryReport({
    required this.totalInstalls,
    required this.activeToday,
    required this.activePast7Days,
    required this.versionDistribution,
    required this.weatherBannerEnabledCount,
    required this.weatherBannerDisabledCount,
    required this.recentPings,
  });
}

class TelemetryPingItem {
  final String deviceId;
  final String version;
  final bool weatherBanner;
  final DateTime timestamp;

  TelemetryPingItem({
    required this.deviceId,
    required this.version,
    required this.weatherBanner,
    required this.timestamp,
  });
}

/// Service handling anonymous, privacy-preserving staff usage telemetry.
/// Reports anonymous device heartbeats to the private Aman6390/metnet-user-data repo.
class TelemetryService {
  static const String _issuesApi =
      'https://api.github.com/repos/Aman6390/metnet-user-data/issues';
  static const String _prefDeviceIdKey = 'pref_telemetry_device_uuid';
  static const String _prefLastPingKey = 'pref_telemetry_last_ping_ms';

  // XOR-masked token bytes for Aman6390/metnet-user-data (Issues: Read/Write)
  static const List<int> _maskedToken = [
    48, 62, 35, 63, 34, 53, 8, 39, 54, 35, 8, 102, 102, 21, 3, 97, 27, 99, 1, 6,
    103, 13, 19, 26, 20, 28, 101, 36, 21, 7, 5, 53, 17, 8, 99, 0, 5, 102, 18, 96,
    58, 3, 33, 1, 59, 15, 103, 30, 103, 37, 36, 25, 19, 6, 16, 21, 6, 21, 98, 59,
    56, 18, 29, 37, 102, 60, 46, 51, 35, 15, 24, 32, 26, 13, 102, 111, 35, 18, 5,
    1, 21, 20, 26, 27, 100, 50, 21, 62, 24, 102, 51, 39, 53
  ];
  static const int _maskKey = 87;
  static String? _cachedToken;

  /// De-obfuscates the isolated repository token in memory.
  static String _getToken() {
    if (_cachedToken != null) return _cachedToken!;
    try {
      _cachedToken = String.fromCharCodes(_maskedToken.map((b) => b ^ _maskKey));
      return _cachedToken!;
    } catch (_) {
      return '';
    }
  }

  /// Retrieves or generates a permanent, anonymous device UUID.
  static Future<String> getOrGenerateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_prefDeviceIdKey);
    if (id == null || id.isEmpty) {
      final rand = Random();
      final partA = rand.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
      final partB = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
      id = 'imd_${partA}_$partB';
      await prefs.setString(_prefDeviceIdKey, id);
    }
    return id;
  }

  /// Sends an anonymous heartbeat ping to Aman6390/metnet-user-data.
  /// Throttled to at most once every 20 hours to prevent spam.
  /// Completely non-blocking and fails silently if offline.
  static Future<void> sendPing({required bool weatherBannerEnabled}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPing = prefs.getInt(_prefLastPingKey) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 20-hour throttling interval
      if (nowMs - lastPing < 20 * 3600 * 1000) {
        return;
      }

      final deviceId = await getOrGenerateDeviceId();
      final token = _getToken();
      if (token.isEmpty) return;

      final payload = {
        'deviceId': deviceId,
        'appVersion': UpdateService.currentVersion,
        'weatherBanner': weatherBannerEnabled,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await http
          .post(
            Uri.parse(_issuesApi),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'IMD-Portal-Telemetry',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'title': 'Ping: $deviceId',
              'body': jsonEncode(payload),
              'labels': ['telemetry', 'v${UpdateService.currentVersion}'],
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 201) {
        await prefs.setInt(_prefLastPingKey, nowMs);
        if (kDebugMode) {
          print('[Telemetry] Successfully sent anonymous heartbeat ping');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Telemetry] Ping failed silently: $e');
      }
    }
  }

  /// Queries all issues in Aman6390/metnet-user-data and computes live Master analytics.
  /// Only accessible when Master Key 6390 is unlocked.
  static Future<TelemetryReport> fetchMasterAnalytics() async {
    final token = _getToken();
    if (token.isEmpty) {
      throw Exception('Telemetry token unavailable');
    }

    final response = await http.get(
      Uri.parse('$_issuesApi?state=all&per_page=100'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'IMD-Portal-Telemetry',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('GitHub API returned ${response.statusCode}: ${response.body}');
    }

    final List<dynamic> issues = jsonDecode(response.body);
    final Map<String, TelemetryPingItem> latestPingByDevice = {};
    final List<TelemetryPingItem> allPings = [];

    for (final issue in issues) {
      try {
        final bodyText = issue['body'] as String? ?? '';
        final parsed = jsonDecode(bodyText) as Map<String, dynamic>;
        final deviceId = (parsed['deviceId'] as String? ?? '').trim();
        final version = (parsed['appVersion'] as String? ?? 'Unknown').trim();
        final weatherBanner = parsed['weatherBanner'] == true;
        final tsStr = parsed['timestamp'] as String? ?? issue['created_at'];
        final timestamp = DateTime.tryParse(tsStr) ?? DateTime.now();

        if (deviceId.isNotEmpty && !deviceId.startsWith('test_')) {
          final item = TelemetryPingItem(
            deviceId: deviceId,
            version: version,
            weatherBanner: weatherBanner,
            timestamp: timestamp,
          );
          allPings.add(item);

          // Track most recent ping per unique device ID
          final existing = latestPingByDevice[deviceId];
          if (existing == null || item.timestamp.isAfter(existing.timestamp)) {
            latestPingByDevice[deviceId] = item;
          }
        }
      } catch (_) {}
    }

    final now = DateTime.now();
    final oneDayAgo = now.subtract(const Duration(hours: 24));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    int activeToday = 0;
    int activePast7Days = 0;
    int weatherOn = 0;
    int weatherOff = 0;
    final Map<String, int> versionCounts = {};

    for (final ping in latestPingByDevice.values) {
      if (ping.timestamp.isAfter(oneDayAgo)) activeToday++;
      if (ping.timestamp.isAfter(sevenDaysAgo)) activePast7Days++;

      if (ping.weatherBanner) {
        weatherOn++;
      } else {
        weatherOff++;
      }

      versionCounts[ping.version] = (versionCounts[ping.version] ?? 0) + 1;
    }

    // Sort recent pings descending by timestamp
    allPings.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return TelemetryReport(
      totalInstalls: latestPingByDevice.length,
      activeToday: activeToday,
      activePast7Days: activePast7Days,
      versionDistribution: versionCounts,
      weatherBannerEnabledCount: weatherOn,
      weatherBannerDisabledCount: weatherOff,
      recentPings: allPings.take(20).toList(),
    );
  }
}
