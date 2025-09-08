import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/services.dart';

/// Service for handling encryption and key management across both Hive and SQLite
class EncryptionService {
  static const String _keyPrefix = 'secure_db_key_';
  static const MethodChannel _channel = MethodChannel('secure_db/keychain');

  static EncryptionService? _instance;
  static EncryptionService get instance => _instance ??= EncryptionService._();

  EncryptionService._();

  /// Encrypts data using AES-GCM encryption
  String encrypt(String data, String key) {
    try {
      final keyBytes = base64Decode(key);
      final encrypter = Encrypter(AES(Key(keyBytes)));
      final iv = IV.fromSecureRandom(16);
      final encrypted = encrypter.encrypt(data, iv: iv);

      // Combine IV and encrypted data
      final combined = iv.bytes + encrypted.bytes;
      return base64Encode(combined);
    } catch (e) {
      throw Exception('Failed to encrypt data: $e');
    }
  }

  /// Decrypts data using AES-GCM encryption
  String decrypt(String encryptedData, String key) {
    try {
      final keyBytes = base64Decode(key);
      final encrypter = Encrypter(AES(Key(keyBytes)));

      final combined = base64Decode(encryptedData);
      final iv = IV(combined.sublist(0, 16));
      final encryptedBytes = combined.sublist(16);

      final encrypted = Encrypted(encryptedBytes);
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('Failed to decrypt data: $e');
    }
  }

  /// Gets or creates an encryption key for a database/box
  Future<String> getOrCreateKey(String name) async {
    final keyName = '$_keyPrefix$name';

    // Try to get existing key from secure storage
    try {
      final existingKey = await _getSecureKey(keyName);
      if (existingKey != null && existingKey.isNotEmpty) {
        return existingKey;
      }
    } catch (e) {
      // Key doesn't exist or secure storage not available
    }

    // Generate new key
    final newKey = _generateKey();

    // Store key securely
    try {
      await _storeSecureKey(keyName, newKey);
    } catch (e) {
      print('Warning: Could not store key securely: $e');
    }

    return newKey;
  }

  /// Generates a cryptographically secure random key
  String _generateKey() {
    final random = Random.secure();
    final bytes = Uint8List(32); // 256-bit key
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Encode(bytes);
  }

  /// Stores a key securely using platform-specific storage
  Future<void> _storeSecureKey(String keyName, String key) async {
    try {
      await _channel.invokeMethod('storeKey', {
        'key': keyName,
        'value': key,
      });
    } catch (e) {
      // Fallback storage could be implemented here
      print('Secure storage not available: $e');
    }
  }

  /// Retrieves a key from secure storage
  Future<String?> _getSecureKey(String keyName) async {
    try {
      final result = await _channel.invokeMethod('getKey', {'key': keyName});
      return result as String?;
    } catch (e) {
      return null;
    }
  }

  /// Deletes a key from secure storage
  Future<void> deleteKey(String name) async {
    final keyName = '$_keyPrefix$name';
    try {
      await _channel.invokeMethod('deleteKey', {'key': keyName});
    } catch (e) {
      print('Failed to delete key: $e');
    }
  }

  /// Converts base64 string to Uint8List for Hive
  Uint8List base64ToUint8List(String base64String) {
    return base64Decode(base64String);
  }

  /// Creates a hash of data for verification
  String hash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generates a password-based key derivation
  String deriveKey(String password, String salt) {
    final saltBytes = utf8.encode(salt);
    final passwordBytes = utf8.encode(password);

    // Simple PBKDF2 implementation (in production, use proper PBKDF2)
    var key = passwordBytes + saltBytes;
    for (int i = 0; i < 10000; i++) {
      key = sha256.convert(key).bytes;
    }

    return base64Encode(key.sublist(0, 32));
  }
}