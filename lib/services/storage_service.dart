import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_data.dart';

/// Handles persistent local storage on the Android device using SharedPreferences.
class StorageService {
  static const String _keyUsername = 'imd_username';
  static const String _keyPassword = 'imd_password';
  static const String _keyDashboardData = 'imd_dashboard_data';
  static const String _keyThemeMode = 'imd_theme_mode';

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
