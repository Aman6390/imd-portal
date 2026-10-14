import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_data.dart';

/// Handles persistent local storage on the Android device using SharedPreferences.
class StorageService {
  static const String _keyUsername = 'imd_username';
  static const String _keyPassword = 'imd_password';
  static const String _keyDashboardData = 'imd_dashboard_data';
  static const String _keyThemeMode = 'imd_theme_mode';
  static const String _keyVipKeywords = 'imd_vip_keywords';
  static const String _keyJunkKeywords = 'imd_junk_keywords';
  static const String _keyOcrCache = 'imd_ocr_cache';

  static const List<String> defaultVipKeywords = [
    'scientific assistant',
    's.a.',
    'scientist',
    'transfer',
    'posting',
    'promotion',
    'ldce',
    'macp',
    'leave',
    'allowance',
    'स्थानांतरण',
    'पदोन्नति',
    'वैज्ञानिक सहायक',
  ];

  static const List<String> defaultJunkKeywords = [
    'driver',
    'canteen',
    'cook',
    'mechanic',
    'carpenter',
    'mts',
    'attendant',
    'clerk',
    'steno',
    'stenographer',
    'hindi translator',
    'staff car',
  ];

  /// Saves portal credentials securely in app storage
  static Future<bool> saveCredentials(String username, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUsername, username);
      await prefs.setString(_keyPassword, password);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Loads saved portal credentials
  static Future<(String, String)> loadCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(_keyUsername) ?? '';
      final password = prefs.getString(_keyPassword) ?? '';
      return (username, password);
    } catch (_) {
      return ('', '');
    }
  }

  /// Loads custom or default VIP keywords
  static Future<List<String>> loadVipKeywords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyVipKeywords);
      if (list != null && list.isNotEmpty) {
        return list;
      }
      return List<String>.from(defaultVipKeywords);
    } catch (_) {
      return List<String>.from(defaultVipKeywords);
    }
  }

  /// Saves custom VIP keywords
  static Future<bool> saveVipKeywords(List<String> keywords) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setStringList(_keyVipKeywords, keywords);
    } catch (_) {
      return false;
    }
  }

  /// Loads custom or default Junk keywords
  static Future<List<String>> loadJunkKeywords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyJunkKeywords);
      if (list != null && list.isNotEmpty) {
        return list;
      }
      return List<String>.from(defaultJunkKeywords);
    } catch (_) {
      return List<String>.from(defaultJunkKeywords);
    }
  }

  /// Saves custom Junk keywords
  static Future<bool> saveJunkKeywords(List<String> keywords) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setStringList(_keyJunkKeywords, keywords);
    } catch (_) {
      return false;
    }
  }

  /// Resets VIP and Junk keywords back to original factory defaults
  static Future<void> resetKeywordsToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyVipKeywords);
    await prefs.remove(_keyJunkKeywords);
  }

  /// Loads previously processed circular OCR cache mapping: url -> isVip
  static Future<Map<String, bool>> loadOcrCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyOcrCache);
      if (jsonStr == null || jsonStr.isEmpty) return {};
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as bool));
    } catch (_) {
      return {};
    }
  }

  /// Saves a single OCR result entry to prevent downloading again
  static Future<void> saveOcrCacheEntry(String url, bool isVip) async {
    try {
      final cache = await loadOcrCache();
      cache[url] = isVip;
      // Retain max 150 entries to keep storage negligible
      if (cache.length > 150) {
        final excess = cache.length - 150;
        final keysToRemove = cache.keys.take(excess).toList();
        for (final k in keysToRemove) {
          cache.remove(k);
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyOcrCache, jsonEncode(cache));
    } catch (_) {}
  }

  /// Saves the latest scraped DashboardData to device storage
  static Future<bool> saveDashboardData(DashboardData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_keyDashboardData, data.serialize());
    } catch (_) {
      return false;
    }
  }

  /// Loads cached DashboardData from device storage
  static Future<DashboardData?> loadDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyDashboardData);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      return DashboardData.deserialize(jsonStr);
    } catch (_) {
      return null;
    }
  }

  /// Saves the user's preferred theme mode ('dark' or 'light')
  static Future<void> saveThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, isDark ? 'dark' : 'light');
  }

  /// Loads the saved theme mode preference (defaults to dark)
  static Future<bool> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_keyThemeMode);
    return mode != 'light'; // Default is dark theme
  }
}
