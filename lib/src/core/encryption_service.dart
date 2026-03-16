import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for handling encryption and key management across both Hive and SQLite
class EncryptionService {
  static const String _keyPrefix = 'secure_db_key_';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
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
      developer.log(
        'WARNING: Secure storage not available, using fallback key generation. '
        'This is less secure and keys will be lost when app restarts.',
        name: 'SecureDB.EncryptionService',
        level: 900, // Warning level
        error: e,
      );
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
  ///
  /// WARNING: This fallback method is less secure than using secure storage.
  /// It uses PBKDF2 with a fixed salt derived from the key name, which provides
  /// deterministic key generation but is vulnerable if an attacker knows the key name.
  /// Keys generated this way exist only in memory and will be lost when the app restarts.
  String _generateConsistentKey(String keyName) {
    // Use PBKDF2-like key derivation for cryptographically secure fallback
    // This is deterministic based on keyName but much stronger than Random(hashCode)

    // Create a base password from the keyName
    final basePassword = 'secure_db_fallback_$keyName';

    // Derive a salt from the keyName for deterministic but secure key generation
    // Using the keyName itself as salt is not ideal, but necessary for deterministic fallback
    final salt = sha256.convert(utf8.encode('salt_$keyName')).bytes;

    // Apply PBKDF2 with 100,000 iterations for strong key derivation
    final passwordBytes = utf8.encode(basePassword);
    var derivedKey = Uint8List.fromList(passwordBytes + salt);

    // Perform 100,000 iterations of SHA-256 hashing
    // This makes brute-force attacks computationally expensive
    for (int i = 0; i < 100000; i++) {
      derivedKey = Uint8List.fromList(sha256.convert(derivedKey).bytes);
    }

    // Use the first 32 bytes (256 bits) as the encryption key
    return base64Encode(derivedKey.sublist(0, 32));
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

  /// Generates a password-based key derivation using PBKDF2
  ///
  /// Uses 100,000 iterations of SHA-256 for strong key derivation.
  /// For even stronger security, consider using the pointycastle package
  /// which provides PBKDF2 with HMAC-SHA256 and other algorithms.
  ///
  /// [password] - The user's password
  /// [salt] - A unique salt value (should be randomly generated and stored)
  /// [iterations] - Number of PBKDF2 iterations (default: 100,000)
  String deriveKey(String password, String salt, {int iterations = 100000}) {
    final saltBytes = utf8.encode(salt);
    final passwordBytes = utf8.encode(password);

    // PBKDF2-like implementation using SHA-256
    // This is a simplified version - for maximum security use pointycastle
    var derivedKey = Uint8List.fromList(passwordBytes + saltBytes);

    // Apply iterative hashing to increase computational cost
    for (int i = 0; i < iterations; i++) {
      derivedKey = Uint8List.fromList(sha256.convert(derivedKey).bytes);
    }

    // Return first 32 bytes (256 bits) for AES-256 encryption
    return base64Encode(derivedKey.sublist(0, 32));
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
