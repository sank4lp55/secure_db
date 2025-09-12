import 'package:hive_flutter/hive_flutter.dart';
import 'secure_box.dart';
import '../core/encryption_service.dart';

/// Hive implementation for SecureDB
class SecureHive {
  static SecureHive? _instance;
  static SecureHive get instance => _instance ??= SecureHive._();

  SecureHive._();

  final EncryptionService _encryptionService = EncryptionService.instance;
  final Set<String> _openBoxes = <String>{}; // Track open boxes manually

  /// Initialize Hive (still static as it needs to be called before getting instance)
  static Future<void> init() async {
    await Hive.initFlutter();
  }

  /// Opens a secure Hive box with encryption enabled (Instance method)
  ///
  /// [boxName] - The name of the box to open
  /// [encryptionKey] - Optional custom encryption key
  ///
  /// Returns a [SecureBox] instance
  Future<SecureBox<T>> openBox<T>(
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
  Future<void> closeBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).close();
      _openBoxes.remove(boxName);
    }
  }

  /// Closes all open boxes
  Future<void> closeAllBoxes() async {
    await Hive.close();
    _openBoxes.clear();
  }

  /// Deletes a box and all its data
  Future<void> deleteBox(String boxName) async {
    await Hive.deleteBoxFromDisk(boxName);
    _openBoxes.remove(boxName);
    // Also delete the encryption key
    await _encryptionService.deleteKey('hive_$boxName');
  }

  /// Checks if a box exists on disk
  Future<bool> boxExists(String boxName) async {
    return await Hive.boxExists(boxName);
  }

  /// Gets all currently open box names
  Iterable<String> getOpenBoxNames() {
    return _openBoxes;
  }

  /// Compacts all open boxes
  Future<void> compactAll() async {
    for (final boxName in _openBoxes.toList()) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).compact();
      }
    }
  }

  /// Gets the estimated size of a box in bytes
  Future<int> getBoxSize(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      throw StateError('Box $boxName is not open');
    }

    final box = Hive.box(boxName);
    return box.length * 64; // Rough estimate
  }

  /// Lists all available boxes (returns currently open boxes)
  Future<List<String>> listBoxes() async {
    return _openBoxes.toList();
  }

  /// Checks if a box is currently open
  bool isBoxOpen(String boxName) {
    return Hive.isBoxOpen(boxName);
  }

  /// Gets the number of open boxes
  int get openBoxCount => _openBoxes.length;

  /// Checks if any boxes are open
  bool get hasOpenBoxes => _openBoxes.isNotEmpty;
}
