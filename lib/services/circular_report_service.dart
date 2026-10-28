import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_circular_service.dart';

/// Service that silently reports newly discovered, unindexed MetNet circulars
/// to Git AI (Aman6390/metnet-circulars-index) for central Gemini/Rule enrichment.
class CircularReportService {
  static const String _issuesApi =
      'https://api.github.com/repos/Aman6390/metnet-circulars-index/issues';
  static const String _reportedPrefsKey = 'reported_scout_circular_ids';

  // XOR-masked token bytes to prevent plain-text string inspection in compiled binaries
  static const List<int> _maskedToken = [
    61, 50, 53, 5, 0, 35, 8, 59, 62, 49, 109, 52, 108, 61, 110, 20, 99, 3,
    34, 8, 110, 31, 104, 111, 14, 18, 13, 14, 10, 16, 31, 8, 9, 0, 105, 34,
    10, 104, 15, 55
  ];
  static const int _maskKey = 90;

  static String? _cachedToken;

  /// De-obfuscates the submission token in memory
  static String _getToken() {
    if (_cachedToken != null) return _cachedToken!;
    try {
      _cachedToken = String.fromCharCodes(_maskedToken.map((b) => b ^ _maskKey));
      return _cachedToken!;
    } catch (_) {
      return '';
    }
  }

  /// Silently reports an unindexed circular to Git AI.
  /// Fire-and-forget, strictly capped to 5s timeout, never interrupts app or sync.
  static Future<void> reportIfUnindexed({
    required String title,
    required String url,
    required String date,
    required String section,
    String extractedText = '',
  }) async {
    try {
      final cleanTitle = title.trim();
      final cleanUrl = url.trim();
      if (cleanTitle.isEmpty || cleanUrl.isEmpty) return;

      // 1. FAST-PATH: If Git AI central index already has this circular, skip immediately
      if (AiCircularService.hasCloudIndexFor(cleanUrl, cleanTitle)) {
        return;
      }

      // 2. DEVICE DEDUPLICATION: Check if this phone already submitted it
      final prefs = await SharedPreferences.getInstance();
      final reportedIds = prefs.getStringList(_reportedPrefsKey) ?? [];
      final localId = _generateId(cleanUrl, cleanTitle);
      if (reportedIds.contains(localId)) {
        return;
      }

      final token = _getToken();
      if (token.isEmpty) return;

      // 3. Prepare sanitized payload (max 4000 chars of extracted text)
      final payload = {
        'title': cleanTitle,
        'url': cleanUrl,
        'date': date.trim(),
        'section': section.trim(),
        'extracted_text': extractedText.length > 4000
            ? extractedText.substring(0, 4000)
            : extractedText,
      };

      final issueBody = '```json\n${json.encode(payload)}\n```';
      final issueTitle = '[NEW CIRCULAR] $cleanTitle';

      final response = await http
          .post(
            Uri.parse(_issuesApi),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/vnd.github.v3+json',
              'Content-Type': 'application/json',
              'User-Agent': 'IMD-Portal-Scout/1.4.22',
            },
            body: json.encode({
              'title': issueTitle,
              'body': issueBody,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        reportedIds.add(localId);
        // Keep bounded to last 200 IDs
        if (reportedIds.length > 200) {
          reportedIds.removeRange(0, reportedIds.length - 200);
        }
        await prefs.setStringList(_reportedPrefsKey, reportedIds);
        debugPrint('[Scout] Successfully submitted circular ticket to Git AI: $cleanTitle');
      }
    } catch (_) {
      // Fire-and-forget: silently ignore errors so scraping / sync is 100% resilient
    }
  }

  static String _generateId(String url, String title) {
    return '${url.hashCode}_${title.hashCode}';
  }
}
