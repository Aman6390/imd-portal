import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles 30-Day Beta Trial management, Device ID generation,
/// and offline cryptographic HMAC license verification.
class LicenseService {
  static const String masterVipKey = 'IMD-VIP-9K4F-8X2M-6390';
  static const String adminPin = '6390';
  static const String _secretSalt = 'IMD_METNET_PORTAL_SECURE_SALT_2026';

  static const String _keyDeviceId = 'imd_device_id';
  static const String _keyTrialStart = 'imd_trial_start_epoch';
  static const String _keyIsActivated = 'imd_is_activated';
  static const String _keyIsOwner = 'imd_is_owner';
  static const String _keyLicenseKey = 'imd_license_key';

  /// Retrieves or initializes a unique, persistent Device Installation ID
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(4, (i) => random.nextInt(256));
      final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
      id = 'IMD-${hex.substring(0, 4)}-${hex.substring(4, 8)}';
      await prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  /// Calculates a deterministic, offline cryptographic license key for a given Device ID
  static String generateKeyForDevice(String deviceId) {
    final cleanId = deviceId.trim().toUpperCase();
    final hmac = Hmac(sha256, utf8.encode(_secretSalt));
    final digest = hmac.convert(utf8.encode(cleanId));
    final hexString = digest.toString().toUpperCase();
    final part1 = hexString.substring(0, 4);
    final part2 = hexString.substring(4, 8);
    return 'PRO-$part1-$part2';
  }

  /// Verifies an entered activation key (Device Key or Master VIP Key)
  static Future<(bool, String)> verifyAndActivate(String inputKey) async {
    final cleanInput = inputKey.trim().toUpperCase();
    if (cleanInput.isEmpty) {
      return (false, 'Please enter an activation key.');
    }

    final prefs = await SharedPreferences.getInstance();

    // Check Master VIP Key (Owner Mode)
    if (cleanInput == masterVipKey) {
      await prefs.setBool(_keyIsActivated, true);
      await prefs.setBool(_keyIsOwner, true);
      await prefs.setString(_keyLicenseKey, cleanInput);
      return (true, '✨ Master VIP Key accepted! Owner & Pro features unlocked.');
    }

    // Check Device-Specific Key
    final deviceId = await getDeviceId();
    final expectedKey = generateKeyForDevice(deviceId);

    if (cleanInput == expectedKey) {
      await prefs.setBool(_keyIsActivated, true);
      await prefs.setBool(_keyIsOwner, false);
      await prefs.setString(_keyLicenseKey, cleanInput);
      return (true, '✨ Device Key accepted! Pro lifetime license unlocked.');
    }

    return (false, '❌ Invalid key. Keys are unique to each Device ID.');
  }

  /// Checks if the app is currently activated with a valid Pro license
  static Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsActivated) ?? false;
  }

  /// Checks if this device was activated using the Master VIP Key (Owner Mode)
  static Future<bool> isOwner() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsOwner) ?? false;
  }

  /// Calculates remaining trial days (out of 30 days)
  static Future<int> getRemainingTrialDays() async {
    if (await isActivated()) {
      return 9999; // Activated permanently
    }

    final prefs = await SharedPreferences.getInstance();
    int? startEpoch = prefs.getInt(_keyTrialStart);
    if (startEpoch == null) {
      startEpoch = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_keyTrialStart, startEpoch);
    }

    final startDate = DateTime.fromMillisecondsSinceEpoch(startEpoch);
    final daysPassed = DateTime.now().difference(startDate).inDays;
    final remaining = 30 - daysPassed;
    return remaining > 0 ? remaining : 0;
  }

  /// Verifies whether the app can currently sync (Trial active or Pro activated)
  static Future<bool> canUseApp() async {
    if (await isActivated()) return true;
    final remainingDays = await getRemainingTrialDays();
    return remainingDays > 0;
  }

  /// Verifies the secret 4-digit Admin PIN to open the in-app key generator
  static bool verifyAdminPin(String inputPin) {
    return inputPin.trim() == adminPin;
  }
}
