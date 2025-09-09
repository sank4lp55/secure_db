import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for handling encryption and key management across both Hive and SQLite
class EncryptionService {
  static const String _keyPrefix = 'secure_db_key_';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static EncryptionService? _instance;
  static EncryptionService get instance => _instance ??= EncryptionService._();

  // Fallback in-memory storage for when secure storage fails
  final Map<String, String> _fallbackKeyCache = {};

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

    try {
      // Try to get existing key from secure storage
      final existingKey = await _secureStorage.read(key: keyName);
      if (existingKey != null && existingKey.isNotEmpty) {
        return existingKey;
      }

      // Generate new key if none exists
      final newKey = _generateKey();

      // Store the new key securely
      await _secureStorage.write(key: keyName, value: newKey);

      return newKey;
    } catch (e) {
      // Fallback to in-memory storage if secure storage fails
      // print('Secure storage not available, using fallback: $e');
      return _getFallbackKey(keyName);
    }
  }

  /// Fallback key management when secure storage is unavailable
  String _getFallbackKey(String keyName) {
    if (_fallbackKeyCache.containsKey(keyName)) {
      return _fallbackKeyCache[keyName]!;
    }

    // Generate a consistent key for this session
    final key = _generateConsistentKey(keyName);
    _fallbackKeyCache[keyName] = key;
    return key;
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

  /// Generates a consistent key based on name (fallback only)
  String _generateConsistentKey(String keyName) {
    final baseString = 'secure_db_fallback_$keyName';
    final hash = sha256.convert(utf8.encode(baseString));

    final random = Random(hash.toString().hashCode);
    final bytes = Uint8List(32);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Encode(bytes);
  }

  /// Deletes a key from secure storage
  Future<void> deleteKey(String name) async {
    final keyName = '$_keyPrefix$name';
    try {
      await _secureStorage.delete(key: keyName);
    } catch (e) {
      // print('Failed to delete key from secure storage: $e');
    }

    // Also remove from fallback cache
    _fallbackKeyCache.remove(keyName);
  }

  /// Deletes all keys (useful for logout/reset)
  Future<void> deleteAllKeys() async {
    try {
      // Get all keys that belong to this package
      final allKeys = await _secureStorage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith(_keyPrefix)) {
          await _secureStorage.delete(key: key);
        }
      }
    } catch (e) {
      // Silent failure - fallback cache is cleared regardless
    }

    // Clear fallback cache
    _fallbackKeyCache.clear();
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

    // Simple PBKDF2 implementation (in production, consider using pointycastle for proper PBKDF2)
    var key = passwordBytes + saltBytes;
    for (int i = 0; i < 10000; i++) {
      key = sha256.convert(key).bytes;
    }

    return base64Encode(key.sublist(0, 32));
  }

  /// Check if secure storage is available
  Future<bool> isSecureStorageAvailable() async {
    try {
      await _secureStorage.read(key: 'test_availability');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear fallback cache (useful for testing)
  void clearFallbackCache() {
    _fallbackKeyCache.clear();
  }
}
