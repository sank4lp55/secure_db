import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'secure_database.dart';
import '../core/encryption_service.dart';
import '../core/db_config.dart';

/// SQLite implementation for SecureDB
class SecureSQLite {
  static SecureSQLite? _instance;
  static SecureSQLite get instance => _instance ??= SecureSQLite._();

  SecureSQLite._();

  final EncryptionService _encryptionService = EncryptionService.instance;
  final Map<String, SecureDatabase> _databases = {};
  DbConfig _config = DbConfig.defaultConfig;

  /// Initialize SQLite (still static as it needs to be called before getting instance)
  static Future<void> init({DbConfig? config}) async {
    instance._config = config ?? DbConfig.defaultConfig;

    if (instance._config.enableLogging) {
      debugPrint('SecureSQLite initialized with config: ${instance._config}');
    }
  }

  /// Opens a secure SQLite database (Instance method)
  ///
  /// [databaseName] - Name of the database file
  /// [version] - Database version for migrations
  /// [onCreate] - Function called when database is created
  /// [onUpgrade] - Function called when database needs upgrade
  /// [encryptionKey] - Optional custom encryption key
  ///
  /// Returns a [SecureDatabase] instance
  Future<SecureDatabase> openDatabase(
      String databaseName, {
        int? version,
        Future<void> Function(SecureDatabase db, int version)? onCreate,
        Future<void> Function(SecureDatabase db, int oldVersion, int newVersion)?
        onUpgrade,
        String? encryptionKey,
      }) async {
    // Check if database is already open
    if (_databases.containsKey(databaseName)) {
      return _databases[databaseName]!;
    }

    // Generate or retrieve encryption key
    final key = encryptionKey ??
        await _encryptionService.getOrCreateKey('sqlite_$databaseName');

    // Get database path
    final databasePath = _config.databasePath ?? await getDatabasesPath();
    final path = join(databasePath, databaseName);

    if (_config.enableLogging) {
      debugPrint('Opening database at: $path');
    }

    // Open the underlying SQLite database
    // Use the sqflite package's openDatabase function with full qualification
    final Database database = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version ?? _config.version,
        onCreate: onCreate != null
            ? (db, version) async {
          final secureDb = SecureDatabase(db, _encryptionService, key);
          await onCreate(secureDb, version);
        }
            : null,
        onUpgrade: onUpgrade != null
            ? (db, oldVersion, newVersion) async {
          final secureDb = SecureDatabase(db, _encryptionService, key);
          await onUpgrade(secureDb, oldVersion, newVersion);
        }
            : null,
      ),
    );

    // Create secure database wrapper
    final secureDb = SecureDatabase(database, _encryptionService, key);
    _databases[databaseName] = secureDb;

    return secureDb;
  }

  /// Static convenience method for backwards compatibility
  static Future<SecureDatabase> openDatabaseStatic(
      String databaseName, {
        int? version,
        Future<void> Function(SecureDatabase db, int version)? onCreate,
        Future<void> Function(SecureDatabase db, int oldVersion, int newVersion)?
        onUpgrade,
        String? encryptionKey,
      }) async {
    return instance.openDatabase(
      databaseName,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      encryptionKey: encryptionKey,
    );
  }

  /// Closes a specific database
  Future<void> closeDatabase(String databaseName) async {
    final db = _databases[databaseName];
    if (db != null) {
      await db.close();
      _databases.remove(databaseName);
    }
  }

  /// Closes all open databases
  Future<void> closeAll() async {
    for (final db in _databases.values) {
      await db.close();
    }
    _databases.clear();
  }

  /// Static convenience method for closeAll
  static Future<void> closeAllStatic() async {
    return instance.closeAll();
  }

  /// Deletes a database file
  Future<void> deleteDatabase(String databaseName) async {
    // Close the database first
    await closeDatabase(databaseName);

    // Delete the database file
    final databasePath = _config.databasePath ?? await getDatabasesPath();
    final path = join(databasePath, databaseName);
    await databaseFactory.deleteDatabase(path);

    // Delete the encryption key
    await _encryptionService.deleteKey('sqlite_$databaseName');

    if (_config.enableLogging) {
      debugPrint('Deleted database: $path');
    }
  }

  /// Checks if a database file exists
  Future<bool> databaseExists(String databaseName) async {
    final databasePath = _config.databasePath ?? await getDatabasesPath();
    final path = join(databasePath, databaseName);
    return await databaseFactory.databaseExists(path);
  }

  /// Gets the size of a database file in bytes
  Future<int> getDatabaseSize(String databaseName) async {
    final databasePath = _config.databasePath ?? await getDatabasesPath();
    final path = join(databasePath, databaseName);

    try {
      final exists = await databaseFactory.databaseExists(path);
      if (!exists) return 0;

      // This would need platform-specific implementation to get actual file size
      // For now, return 0 as placeholder
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Lists all database files
  Future<List<String>> listDatabases() async {
    try {
      // This would need platform-specific implementation
      // For now, return empty list
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Gets currently open databases
  List<String> getOpenDatabases() {
    return _databases.keys.toList();
  }

  /// Executes a batch operation across multiple databases
  Future<void> executeBatch(
      List<String> databaseNames,
      Future<void> Function(SecureDatabase db) operation,
      ) async {
    for (final dbName in databaseNames) {
      final db = _databases[dbName];
      if (db != null) {
        await operation(db);
      }
    }
  }

  /// Vacuum all open databases to reclaim space
  Future<void> vacuumAll() async {
    for (final db in _databases.values) {
      try {
        await db.execute('VACUUM');
      } catch (e) {
        if (_config.enableLogging) {
          debugPrint('Failed to vacuum database: $e');
        }
      }
    }
  }

  /// Gets database configuration
  DbConfig get config => _config;

  /// Updates database configuration
  void updateConfig(DbConfig newConfig) {
    _config = newConfig;
  }

  /// Checks if a database is currently open
  bool isDatabaseOpen(String databaseName) {
    return _databases.containsKey(databaseName);
  }

  /// Gets the number of open databases
  int get openDatabaseCount => _databases.length;

  /// Checks if any databases are open
  bool get hasOpenDatabases => _databases.isNotEmpty;

  /// Gets a reference to an already open database
  SecureDatabase? getDatabase(String databaseName) {
    return _databases[databaseName];
  }

  /// Executes a SQL query across multiple databases
  Future<Map<String, List<Map<String, Object?>>>> queryMultiple(
      List<String> databaseNames,
      String sql, [
        List<Object?>? arguments,
      ]) async {
    final results = <String, List<Map<String, Object?>>>{};

    for (final dbName in databaseNames) {
      final db = _databases[dbName];
      if (db != null) {
        try {
          results[dbName] = await db.rawQuery(sql, arguments);
        } catch (e) {
          if (_config.enableLogging) {
            debugPrint('Failed to query database $dbName: $e');
          }
          results[dbName] = [];
        }
      }
    }

    return results;
  }

  /// Performs a health check on all open databases
  Future<Map<String, bool>> healthCheck() async {
    final health = <String, bool>{};

    for (final entry in _databases.entries) {
      try {
        await entry.value.rawQuery('SELECT 1');
        health[entry.key] = true;
      } catch (e) {
        health[entry.key] = false;
        if (_config.enableLogging) {
          debugPrint('Database ${entry.key} failed health check: $e');
        }
      }
    }

    return health;
  }

  /// Creates a backup of a database
  Future<void> backupDatabase(
      String databaseName,
      String backupPath,
      ) async {
    final db = _databases[databaseName];
    if (db == null) {
      throw StateError('Database $databaseName is not open');
    }

    // This would need platform-specific implementation for file copying
    // For now, just log the operation
    if (_config.enableLogging) {
      debugPrint('Backup requested for $databaseName to $backupPath');
    }
  }

  /// Restores a database from backup
  Future<void> restoreDatabase(
      String databaseName,
      String backupPath,
      ) async {
    // Close the database if it's open
    await closeDatabase(databaseName);

    // This would need platform-specific implementation for file copying
    // For now, just log the operation
    if (_config.enableLogging) {
      debugPrint('Restore requested for $databaseName from $backupPath');
    }
  }

  /// Optimizes all open databases
  Future<void> optimizeAll() async {
    for (final db in _databases.values) {
      try {
        await db.execute('ANALYZE');
        await db.execute('PRAGMA optimize');
      } catch (e) {
        if (_config.enableLogging) {
          debugPrint('Failed to optimize database: $e');
        }
      }
    }
  }

  /// Sets WAL mode for all open databases
  Future<void> enableWalMode() async {
    for (final db in _databases.values) {
      try {
        await db.execute('PRAGMA journal_mode=WAL');
      } catch (e) {
        if (_config.enableLogging) {
          debugPrint('Failed to enable WAL mode: $e');
        }
      }
    }
  }

  /// Gets database statistics
  Future<Map<String, Map<String, dynamic>>> getStatistics() async {
    final stats = <String, Map<String, dynamic>>{};

    for (final entry in _databases.entries) {
      try {
        stats[entry.key] = {
          'isOpen': entry.value.isOpen,
          'path': entry.value.path,
          'tables': await entry.value.getTableNames(),
        };
      } catch (e) {
        stats[entry.key] = {
          'error': e.toString(),
        };
      }
    }

    return stats;
  }

  // ===== Static convenience methods for backwards compatibility =====

  static Future<void> closeDatabaseStatic(String databaseName) async {
    return instance.closeDatabase(databaseName);
  }

  static Future<void> deleteDatabaseStatic(String databaseName) async {
    return instance.deleteDatabase(databaseName);
  }

  static Future<bool> databaseExistsStatic(String databaseName) async {
    return instance.databaseExists(databaseName);
  }

  static List<String> getOpenDatabasesStatic() {
    return instance.getOpenDatabases();
  }

  static DbConfig get configStatic => instance.config;

  static void updateConfigStatic(DbConfig newConfig) {
    instance.updateConfig(newConfig);
  }
}