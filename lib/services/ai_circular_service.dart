import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_circular_entry.dart';

/// Service responsible for fetching, caching, and matching AI-extracted
/// semantic summaries and cadre tags from the central cloud repository.
class AiCircularService {
  static const String _rawIndexUrl =
      'https://raw.githubusercontent.com/Aman6390/imd-portal/main/data/circulars_ai_index.json';
  static const String _cacheKey = 'cached_circulars_ai_index';
  static const String _prefUserEnabledKey = 'pref_enable_ai_summaries';

  static Map<String, AiCircularEntry> _entriesByUrl = {};
  static Map<String, AiCircularEntry> _entriesByNormalizedTitle = {};
  static bool _isKillSwitchActive = false;
  static bool _isInitialized = false;

  /// Check if the AI semantic feature is enabled both globally and by user
  static Future<bool> isAiEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final userPref = prefs.getBool(_prefUserEnabledKey) ?? true;
    return userPref && !_isKillSwitchActive;
  }

  /// Toggle user preference for AI summaries
  static Future<void> setUserEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefUserEnabledKey, enabled);
  }

  /// Initialize and load cached AI metadata from storage on startup
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        _parseAndLoadIndex(cachedJson);
      }
    } catch (_) {}
    _isInitialized = true;
  }

  /// Fetch the latest AI index from GitHub with a 5-second safety timeout
  static Future<void> syncIndex() async {
    await initialize();

    try {
      final response = await http
          .get(Uri.parse(_rawIndexUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        _parseAndLoadIndex(response.body);

        // Cache locally for offline access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, response.body);
      }
    } catch (_) {
      // Offline or network timeout - gracefully retain cached index
    }
  }

  /// Parse the raw JSON index into fast in-memory lookup maps
  static void _parseAndLoadIndex(String rawJson) {
    try {
      final Map<String, dynamic> decoded = json.decode(rawJson);
      
      // Remote Kill-Switch Check
      final bool globalEnabled = decoded['enable_ai_index'] as bool? ?? true;
      _isKillSwitchActive = !globalEnabled;

      if (_isKillSwitchActive) {
        _entriesByUrl.clear();
        _entriesByNormalizedTitle.clear();
        return;
      }

      final Map<String, dynamic>? circulars =
          decoded['circulars'] as Map<String, dynamic>?;

      if (circulars == null) return;

      final byUrl = <String, AiCircularEntry>{};
      final byTitle = <String, AiCircularEntry>{};

      circulars.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final entry = AiCircularEntry.fromMap(value);
          if (entry.url.isNotEmpty) {
            byUrl[entry.url.trim().toLowerCase()] = entry;
          }
          final normTitle = _normalizeTitle(entry.title);
          if (normTitle.isNotEmpty) {
            byTitle[normTitle] = entry;
          }
        }
      });

      _entriesByUrl = byUrl;
      _entriesByNormalizedTitle = byTitle;
    } catch (_) {}
  }

  /// Lookup AI semantic metadata for a circular by URL or fallback by Title
  static AiCircularEntry? getMetadata(String? url, String? title) {
    if (_isKillSwitchActive) return null;

    if (url != null && url.isNotEmpty) {
      final cleanUrl = url.trim().toLowerCase();
      if (_entriesByUrl.containsKey(cleanUrl)) {
        return _entriesByUrl[cleanUrl];
      }
    }

    if (title != null && title.isNotEmpty) {
      final normTitle = _normalizeTitle(title);
      if (_entriesByNormalizedTitle.containsKey(normTitle)) {
        return _entriesByNormalizedTitle[normTitle];
      }
    }

    return null;
  }

  /// Normalize circular title by removing punctuation and extra whitespace
  static String _normalizeTitle(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u0900-\u097F]'), '')
        .trim();
  }
}
