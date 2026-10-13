import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Handles device biometric, fingerprint, face, and device PIN/passcode authentication.
class AuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if the device has biometric hardware or screen lock security configured.
  static Future<bool> canAuthenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      return isSupported || canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user with the native biometric prompt (Fingerprint / Face / PIN / Pattern).
  /// [biometricOnly] is false so it gracefully falls back to device PIN/Pattern/Password.
  static Future<bool> authenticate({required String localizedReason}) async {
    try {
      final supported = await canAuthenticate();
      if (!supported) {
        // If device has no screen lock or biometrics setup, allow access to prevent lockout
        return true;
      }

      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      print('Auth error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected auth error: $e');
      return false;
    }
  }
}
