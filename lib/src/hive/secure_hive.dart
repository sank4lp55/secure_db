import 'package:hive_flutter/hive_flutter.dart';
import 'secure_box.dart';
import '../core/encryption_service.dart';

/// Hive implementation for SecureDB
class SecureHive {
  static final EncryptionService _encryptionService =
      EncryptionService.instance;
  static final Set<String> _openBoxes = <String>{}; // Track open boxes manually

  /// Initialize Hive
  static Future<void> init() async {
    await Hive.initFlutter();
  }

  /// Opens a secure Hive box with encryption enabled
  ///
  /// [boxName] - The name of the box to open
  /// [encryptionKey] - Optional custom encryption key
  ///
  /// Returns a [SecureBox] instance
  static Future<SecureBox<T>> openBox<T>(
    String boxName, {
    String? encryptionKey,
  }) async {
    // Generate or retrieve encryption key
    final key = encryptionKey ??
        await _encryptionService.getOrCreateKey('hive_$boxName');

    // Create Hive encryption cipher
    final encryptionCipher =
        HiveAesCipher(_encryptionService.base64ToUint8List(key));

    // Open the underlying Hive box with encryption
    final box = await Hive.openBox<String>(
      boxName,
      encryptionCipher: encryptionCipher,
    );

    // Track the opened box
    _openBoxes.add(boxName);

    return SecureBox<T>(box, _encryptionService, key);
  }

  /// Closes a specific box
  static Future<void> closeBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).close();
      _openBoxes.remove(boxName);
    }
  }

  /// Closes all open boxes
  static Future<void> closeAllBoxes() async {
    await Hive.close();
    _openBoxes.clear();
  }

  /// Deletes a box and all its data
  static Future<void> deleteBox(String boxName) async {
    await Hive.deleteBoxFromDisk(boxName);
    _openBoxes.remove(boxName);
    // Also delete the encryption key
    await _encryptionService.deleteKey('hive_$boxName');
  }

  /// Checks if a box exists on disk
  static Future<bool> boxExists(String boxName) async {
    return await Hive.boxExists(boxName);
  }

  /// Gets all currently open box names
  static Iterable<String> getOpenBoxNames() {
    return _openBoxes;
  }

  /// Compacts all open boxes
  static Future<void> compactAll() async {
    for (final boxName in _openBoxes.toList()) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).compact();
      }
    }
  }

  /// Gets the estimated size of a box in bytes
  static Future<int> getBoxSize(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      throw StateError('Box $boxName is not open');
    }

    final box = Hive.box(boxName);
    return box.length * 64; // Rough estimate
  }

  /// Lists all available boxes (returns currently open boxes)
  static Future<List<String>> listBoxes() async {
    return _openBoxes.toList();
  }

  /// Checks if a box is currently open
  static bool isBoxOpen(String boxName) {
    return Hive.isBoxOpen(boxName);
  }

  /// Gets the number of open boxes
  static int get openBoxCount => _openBoxes.length;

  /// Checks if any boxes are open
  static bool get hasOpenBoxes => _openBoxes.isNotEmpty;
}
