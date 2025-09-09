import '../hive/secure_hive.dart';
import '../sqlite/secure_sqlite.dart';
import 'db_config.dart';

/// Main interface for SecureDB operations
/// Provides unified access to both Hive and SQLite implementations
class SecureDB {
  /// Initialize SecureDB with default configuration
  static Future<void> init({DbConfig? config}) async {
    await SecureHive.init();
    await SecureSQLite.init(config: config);
  }

  /// Factory method to create Hive-based secure storage
  ///
  /// Example:
  /// ```dart
  /// final box = await SecureDB.hive().openBox<String>('userSettings');
  /// ```
  static SecureHive hive() {
    return SecureHive();
  }

  /// Factory method to create SQLite-based secure storage
  ///
  /// Example:
  /// ```dart
  /// final db = await SecureDB.sqlite().openDatabase('app.db');
  /// ```
  static SecureSQLite sqlite() {
    return SecureSQLite();
  }

  /// Quick access method for simple key-value storage using Hive
  ///
  /// Example:
  /// ```dart
  /// await SecureDB.setString('username', 'john_doe');
  /// String? username = await SecureDB.getString('username');
  /// ```
  static Future<void> setString(String key, String value,
      {String boxName = 'default'}) async {
    final box = await SecureHive.openBox<String>(boxName);
    await box.put(key, value);
  }

  static Future<String?> getString(String key,
      {String boxName = 'default'}) async {
    final box = await SecureHive.openBox<String>(boxName);
    return box.get(key);
  }

  static Future<void> setInt(String key, int value,
      {String boxName = 'default'}) async {
    final box = await SecureHive.openBox<int>(boxName);
    await box.put(key, value);
  }

  static Future<int?> getInt(String key, {String boxName = 'default'}) async {
    final box = await SecureHive.openBox<int>(boxName);
    return box.get(key);
  }

  static Future<void> setBool(String key, bool value,
      {String boxName = 'default'}) async {
    final box = await SecureHive.openBox<bool>(boxName);
    await box.put(key, value);
  }

  static Future<bool?> getBool(String key, {String boxName = 'default'}) async {
    final box = await SecureHive.openBox<bool>(boxName);
    return box.get(key);
  }

  static Future<void> setMap(String key, Map<String, dynamic> value,
      {String boxName = 'default'}) async {
    final box = await SecureHive.openBox<Map<String, dynamic>>(boxName);
    await box.put(key, value);
  }

  static Future<Map<String, dynamic>?> getMap(String key,
      {String boxName = 'default'}) async {
    final box = await SecureHive.openBox<Map<String, dynamic>>(boxName);
    return box.get(key);
  }

  /// Remove a key from storage
  static Future<void> remove(String key, {String boxName = 'default'}) async {
    final box = await SecureHive.openBox(boxName);
    await box.delete(key);
  }

  /// Clear all data from a box
  static Future<void> clearBox(String boxName) async {
    final box = await SecureHive.openBox(boxName);
    await box.clear();
  }

  /// Close all databases and clean up resources
  static Future<void> closeAll() async {
    await SecureHive.closeAllBoxes();
    await SecureSQLite.closeAll();
  }
}
