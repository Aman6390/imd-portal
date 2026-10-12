import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/asymmetric/api.dart';

/// Cryptography helper strictly matching Python's PyCryptodome PKCS1_v1_5 logic.
class RsaCrypto {
  /// Encrypts a plaintext string (e.g. password) with RSA PKCS1_v1_5 using the provided PEM public key.
  /// Returns a Base64 encoded string matching Python's base64.b64encode(cipher.encrypt(...)).
  static String encryptPassword(String plainText, String pemPublicKey) {
    try {
      // Clean and normalize PEM string if needed
      String cleanedPem = pemPublicKey.trim();
      if (!cleanedPem.contains('-----BEGIN PUBLIC KEY-----')) {
        cleanedPem = '-----BEGIN PUBLIC KEY-----\n$cleanedPem\n-----END PUBLIC KEY-----';
      }

      // Parse RSA Public Key using encrypt package
      final parser = enc.RSAKeyParser();
      final RSAPublicKey publicKey = parser.parse(cleanedPem) as RSAPublicKey;

      // Encrypt with PKCS1_v1_5 encoding using encrypt's high-level Encrypter
      final encrypter = enc.Encrypter(
        enc.RSA(
          publicKey: publicKey,
          encoding: enc.RSAEncoding.PKCS1,
        ),
      );

      final encrypted = encrypter.encrypt(plainText);
      return encrypted.base64;
    } catch (e) {
      throw Exception('RSA Encryption failed: $e');
    }
  }
}
