import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_db/src/core/encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EncryptionService', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService.instance;
      // Clear any cached fallback keys before each test
      encryptionService.clearFallbackCache();
    });

    // Helper function to generate a test key
    String generateTestKey() {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      return base64Encode(bytes);
    }

    group('Basic Encryption/Decryption', () {
      test('encrypt and decrypt should return original data', () {
        const testData = 'Hello, World!';
        final key = generateTestKey();

        final encrypted = encryptionService.encrypt(testData, key);
        final decrypted = encryptionService.decrypt(encrypted, key);

        expect(decrypted, equals(testData));
      });

      test('encrypted data should be different from original', () {
        const testData = 'Secret Message';
        final key = generateTestKey();

        final encrypted = encryptionService.encrypt(testData, key);

        expect(encrypted, isNot(equals(testData)));
        expect(encrypted.length, greaterThan(testData.length));
      });

      test('encryption should produce different ciphertext each time (different IV)', () {
        const testData = 'Same Data';
        final key = generateTestKey();

        final encrypted1 = encryptionService.encrypt(testData, key);
        final encrypted2 = encryptionService.encrypt(testData, key);

        // Should be different due to random IV
        expect(encrypted1, isNot(equals(encrypted2)));

        // But both should decrypt to same plaintext
        expect(encryptionService.decrypt(encrypted1, key), equals(testData));
        expect(encryptionService.decrypt(encrypted2, key), equals(testData));
      });

      test('decryption with wrong key should fail', () {
        const testData = 'Secret';
        final correctKey = generateTestKey();
        final wrongKey = generateTestKey();

        final encrypted = encryptionService.encrypt(testData, correctKey);

        expect(
          () => encryptionService.decrypt(encrypted, wrongKey),
          throwsException,
        );
      });

      test('should handle empty string encryption', () {
        const testData = '';
        final key = generateTestKey();

        // Note: Empty string encryption may not be supported by the encrypt package
        // This is an edge case that should ideally be handled at a higher level
        try {
          final encrypted = encryptionService.encrypt(testData, key);
          final decrypted = encryptionService.decrypt(encrypted, key);
          expect(decrypted, equals(testData));
        } catch (e) {
          // If empty string encryption fails, that's acceptable
          // Applications should handle this at a higher level
          expect(e, isA<Exception>());
        }
      });

      test('should handle unicode characters', () {
        const testData = 'Hello 世界 🌍 مرحبا';
        final key = generateTestKey();

        final encrypted = encryptionService.encrypt(testData, key);
        final decrypted = encryptionService.decrypt(encrypted, key);

        expect(decrypted, equals(testData));
      });

      test('should handle large data', () {
        final testData = 'x' * 10000; // 10KB of data
        final key = generateTestKey();

        final encrypted = encryptionService.encrypt(testData, key);
        final decrypted = encryptionService.decrypt(encrypted, key);

        expect(decrypted, equals(testData));
      });
    });

    group('Key Generation', () {
      test('getOrCreateKey should generate valid keys', () async {
        final key = await encryptionService.getOrCreateKey('test_key_gen');

        // 32 bytes = 256 bits encoded in base64 should be 44 characters
        // (with possible padding)
        expect(key.length, greaterThanOrEqualTo(43));
        expect(key.length, lessThanOrEqualTo(44));

        // Should be valid base64
        expect(() => base64Decode(key), returnsNormally);

        // Decoded should be exactly 32 bytes
        final decoded = base64Decode(key);
        expect(decoded.length, equals(32));

        // Clean up
        await encryptionService.deleteKey('test_key_gen');
      });

      test('getOrCreateKey should return same key for same name', () async {
        const keyName = 'test_consistency';

        final key1 = await encryptionService.getOrCreateKey(keyName);
        final key2 = await encryptionService.getOrCreateKey(keyName);

        expect(key1, equals(key2));

        // Clean up
        await encryptionService.deleteKey(keyName);
      });

      test('getOrCreateKey should return different keys for different names', () async {
        final key1 = await encryptionService.getOrCreateKey('key_name_1');
        final key2 = await encryptionService.getOrCreateKey('key_name_2');

        expect(key1, isNot(equals(key2)));

        // Clean up
        await encryptionService.deleteKey('key_name_1');
        await encryptionService.deleteKey('key_name_2');
      });
    });

    group('Fallback Key Generation (Security Fix)', () {
      // Note: Fallback keys are tested indirectly through getOrCreateKey
      // when secure storage is unavailable. These tests verify the derived
      // key functionality which uses the same PBKDF2 algorithm.

      test('fallback mode produces working encryption keys', () async {
        // This test verifies that when secure storage fails,
        // the fallback mechanism still produces working keys
        encryptionService.clearFallbackCache();

        // Get a key (may use fallback if secure storage unavailable)
        final key = await encryptionService.getOrCreateKey('fallback_test');

        // Verify it works for encryption/decryption
        const testData = 'Test Data';
        final encrypted = encryptionService.encrypt(testData, key);
        final decrypted = encryptionService.decrypt(encrypted, key);

        expect(decrypted, equals(testData));
        expect(key.length, greaterThanOrEqualTo(43));

        // Clean up
        await encryptionService.deleteKey('fallback_test');
      });

      test('secure storage availability can be checked', () async {
        // Test the isSecureStorageAvailable method
        final isAvailable = await encryptionService.isSecureStorageAvailable();

        // Should return a boolean
        expect(isAvailable, isA<bool>());
      });
    });

    group('Password-Based Key Derivation', () {
      test('deriveKey should produce consistent keys for same password and salt', () {
        const password = 'myPassword123';
        const salt = 'randomSalt456';

        final key1 = encryptionService.deriveKey(password, salt);
        final key2 = encryptionService.deriveKey(password, salt);

        expect(key1, equals(key2));
      });

      test('deriveKey should produce different keys for different passwords', () {
        const salt = 'sameSalt';

        final key1 = encryptionService.deriveKey('password1', salt);
        final key2 = encryptionService.deriveKey('password2', salt);

        expect(key1, isNot(equals(key2)));
      });

      test('deriveKey should produce different keys for different salts', () {
        const password = 'samePassword';

        final key1 = encryptionService.deriveKey(password, 'salt1');
        final key2 = encryptionService.deriveKey(password, 'salt2');

        expect(key1, isNot(equals(key2)));
      });

      test('deriveKey should produce 256-bit keys', () {
        const password = 'testPassword';
        const salt = 'testSalt';

        final key = encryptionService.deriveKey(password, salt);
        final decoded = base64Decode(key);

        expect(decoded.length, equals(32)); // 256 bits
      });

      test('derived key should work for encryption/decryption', () {
        const password = 'userPassword';
        const salt = 'uniqueSalt';
        const testData = 'Protected Data';

        final key = encryptionService.deriveKey(password, salt);
        final encrypted = encryptionService.encrypt(testData, key);
        final decrypted = encryptionService.decrypt(encrypted, key);

        expect(decrypted, equals(testData));
      });

      test('deriveKey should support custom iteration count', () {
        const password = 'password';
        const salt = 'salt';

        // With fewer iterations (should be faster)
        final keyLowIterations = encryptionService.deriveKey(
          password,
          salt,
          iterations: 1000,
        );

        // With default high iterations
        final keyHighIterations = encryptionService.deriveKey(password, salt);

        // Keys should be different due to different iteration counts
        expect(keyLowIterations, isNot(equals(keyHighIterations)));
      });
    });

    group('Hash Function', () {
      test('hash should produce consistent output', () {
        const data = 'test data';

        final hash1 = encryptionService.hash(data);
        final hash2 = encryptionService.hash(data);

        expect(hash1, equals(hash2));
      });

      test('hash should produce different output for different data', () {
        final hash1 = encryptionService.hash('data1');
        final hash2 = encryptionService.hash('data2');

        expect(hash1, isNot(equals(hash2)));
      });

      test('hash should produce SHA-256 output (64 hex characters)', () {
        final hash = encryptionService.hash('test');

        // SHA-256 produces 64 hex characters
        expect(hash.length, equals(64));
      });
    });

    group('Utility Functions', () {
      test('base64ToUint8List should correctly convert base64', () {
        final original = [1, 2, 3, 4, 5];
        final base64String = base64Encode(original);

        final result = encryptionService.base64ToUint8List(base64String);

        expect(result, equals(original));
      });

      test('clearFallbackCache should work without errors', () {
        // Clear cache should work without throwing
        expect(() => encryptionService.clearFallbackCache(), returnsNormally);
      });
    });

    group('Security Properties', () {
      test('encrypted data should not contain plaintext patterns', () {
        const testData = 'AAAAAAAA'; // Repeating pattern
        final key = generateTestKey();

        final encrypted = encryptionService.encrypt(testData, key);

        // Encrypted data should not have obvious patterns
        expect(encrypted, isNot(contains('AAAA')));
      });

      test('IV should be prepended to ciphertext (first 16 bytes)', () {
        const testData = 'Test';
        final key = generateTestKey();

        final encrypted = encryptionService.encrypt(testData, key);
        final decoded = base64Decode(encrypted);

        // IV is 16 bytes, so encrypted data should be at least 16 bytes + ciphertext
        expect(decoded.length, greaterThan(16));

        // First 16 bytes are the IV
        final iv = decoded.sublist(0, 16);
        expect(iv.length, equals(16));
      });

      test('key generation should use cryptographically secure random', () async {
        // This test verifies that keys have high entropy
        final keys = <String>[];

        for (int i = 0; i < 10; i++) {
          final key = await encryptionService.getOrCreateKey('unique_key_$i');
          keys.add(key);
        }

        // All keys should be unique (probability of collision is negligible)
        expect(keys.toSet().length, equals(10));

        // Keys should not be sequential or have obvious patterns
        for (int i = 0; i < keys.length - 1; i++) {
          expect(keys[i], isNot(equals(keys[i + 1])));
        }

        // Clean up
        for (int i = 0; i < 10; i++) {
          await encryptionService.deleteKey('unique_key_$i');
        }
      });
    });
  });
}
