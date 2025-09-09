import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../core/encryption_service.dart';
import '../models/query_result.dart';

/// A secure wrapper around SQLite database that provides automatic encryption/decryption
class SecureDatabase {
  final DatabaseExecutor _database;
  final EncryptionService _encryptionService;
  final String _encryptionKey;

  SecureDatabase(
      DatabaseExecutor database, this._encryptionService, this._encryptionKey)
      : _database = database;

  /// Execute a raw SQL command
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    return await _database.execute(sql, arguments);
  }

  /// Execute a SELECT query and return encrypted results
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    return await _database.rawQuery(sql, arguments);
  }

  /// Insert data with automatic encryption of specified columns
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
    List<String> encryptedColumns = const [],
  }) async {
    final encryptedValues = _encryptColumns(values, encryptedColumns);
    return await _database.insert(
      table,
      encryptedValues,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  /// Update data with automatic encryption of specified columns
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
    List<String> encryptedColumns = const [],
  }) async {
    final encryptedValues = _encryptColumns(values, encryptedColumns);
    return await _database.update(
      table,
      encryptedValues,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  /// Query data with automatic decryption of specified columns
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    List<String> encryptedColumns = const [],
  }) async {
    final results = await _database.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    return _decryptResults(results, encryptedColumns);
  }

  /// Delete records from table
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return await _database.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Insert or update data (UPSERT)
  Future<int> insertOrUpdate(
    String table,
    Map<String, Object?> values, {
    List<String> conflictColumns = const [],
    List<String> encryptedColumns = const [],
  }) async {
    final encryptedValues = _encryptColumns(values, encryptedColumns);

    if (conflictColumns.isEmpty) {
      return await insert(table, encryptedValues);
    }

    // Build UPSERT query
    final columns = encryptedValues.keys.join(', ');
    final placeholders = List.filled(encryptedValues.length, '?').join(', ');
    final updateClauses = encryptedValues.keys
        .where((col) => !conflictColumns.contains(col))
        .map((col) => '$col = excluded.$col')
        .join(', ');

    final sql = '''
      INSERT INTO $table ($columns) VALUES ($placeholders)
      ON CONFLICT(${conflictColumns.join(', ')}) DO UPDATE SET $updateClauses
    ''';

    final result =
        await _database.rawInsert(sql, encryptedValues.values.toList());
    return result;
  }

  /// Execute multiple operations in a transaction
  Future<T> transaction<T>(
      Future<T> Function(SecureDatabase txn) action) async {
    if (_database is Database) {
      return await (_database as Database).transaction<T>((txn) async {
        final secureTxn =
            SecureDatabase(txn, _encryptionService, _encryptionKey);
        return await action(secureTxn);
      });
    } else {
      // Already in a transaction, just execute the action with current instance
      return await action(this);
    }
  }

  /// Execute a batch of operations
  Future<List<dynamic>> batch(List<BatchOperation> operations) async {
    late Batch batch;

    if (_database is Database) {
      batch = (_database as Database).batch();
    } else {
      throw UnsupportedError('Batch operations not supported in transactions');
    }

    for (final op in operations) {
      switch (op.type) {
        case BatchOperationType.insert:
          final encryptedValues = _encryptColumns(
            op.values!,
            op.encryptedColumns,
          );
          batch.insert(op.table, encryptedValues);
          break;
        case BatchOperationType.update:
          final encryptedValues = _encryptColumns(
            op.values!,
            op.encryptedColumns,
          );
          batch.update(
            op.table,
            encryptedValues,
            where: op.where,
            whereArgs: op.whereArgs,
          );
          break;
        case BatchOperationType.delete:
          batch.delete(
            op.table,
            where: op.where,
            whereArgs: op.whereArgs,
          );
          break;
        case BatchOperationType.rawInsert:
        case BatchOperationType.rawUpdate:
        case BatchOperationType.rawDelete:
          batch.rawInsert(op.sql!, op.arguments);
          break;
      }
    }

    return await batch.commit();
  }

  /// Create a table with automatic encryption support
  Future<void> createTable(
    String tableName,
    Map<String, String> columns, {
    List<String> primaryKey = const [],
    List<String> encryptedColumns = const [],
    Map<String, String> constraints = const {},
  }) async {
    final columnDefinitions = <String>[];

    for (final entry in columns.entries) {
      var definition = '${entry.key} ${entry.value}';
      if (constraints.containsKey(entry.key)) {
        definition += ' ${constraints[entry.key]}';
      }
      columnDefinitions.add(definition);
    }

    if (primaryKey.isNotEmpty) {
      columnDefinitions.add('PRIMARY KEY (${primaryKey.join(', ')})');
    }

    final sql =
        'CREATE TABLE IF NOT EXISTS $tableName (${columnDefinitions.join(', ')})';
    await execute(sql);

    // Store metadata about encrypted columns
    if (encryptedColumns.isNotEmpty) {
      await _storeTableMetadata(tableName, encryptedColumns);
    }
  }

  /// Drop a table
  Future<void> dropTable(String tableName) async {
    await execute('DROP TABLE IF EXISTS $tableName');
    await _removeTableMetadata(tableName);
  }

  /// Get table names
  Future<List<String>> getTableNames() async {
    final results = await rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != '_secure_db_metadata'",
    );
    return results.map((row) => row['name'] as String).toList();
  }

  /// Get column names for a table
  Future<List<String>> getColumnNames(String tableName) async {
    final results = await rawQuery('PRAGMA table_info($tableName)');
    return results.map((row) => row['name'] as String).toList();
  }

  /// Check if table exists
  Future<bool> tableExists(String tableName) async {
    final results = await rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return results.isNotEmpty;
  }

  /// Get database version (only available for Database, not Transaction)
  Future<int> getVersion() async {
    if (_database is Database) {
      return await (_database as Database).getVersion();
    }
    throw UnsupportedError('getVersion not available in transactions');
  }

  /// Set database version (only available for Database, not Transaction)
  Future<void> setVersion(int version) async {
    if (_database is Database) {
      await (_database as Database).setVersion(version);
    } else {
      throw UnsupportedError('setVersion not available in transactions');
    }
  }

  /// Close the database (only available for Database, not Transaction)
  Future<void> close() async {
    if (_database is Database) {
      await (_database as Database).close();
    } else {
      throw UnsupportedError('close not available in transactions');
    }
  }

  /// Check if database is open (only available for Database, not Transaction)
  bool get isOpen {
    if (_database is Database) {
      return (_database as Database).isOpen;
    }
    return true; // Transactions are always "open" while active
  }

  /// Get database path (only available for Database, not Transaction)
  String get path {
    if (_database is Database) {
      return (_database as Database).path;
    }
    throw UnsupportedError('path not available in transactions');
  }

  /// Encrypt specified columns in a map
  Map<String, Object?> _encryptColumns(
    Map<String, Object?> values,
    List<String> encryptedColumns,
  ) {
    if (encryptedColumns.isEmpty) return values;

    final result = <String, Object?>{};

    for (final entry in values.entries) {
      if (encryptedColumns.contains(entry.key) && entry.value != null) {
        final jsonValue = jsonEncode(entry.value);
        result[entry.key] =
            _encryptionService.encrypt(jsonValue, _encryptionKey);
      } else {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// Decrypt specified columns in query results
  List<Map<String, Object?>> _decryptResults(
    List<Map<String, Object?>> results,
    List<String> encryptedColumns,
  ) {
    if (encryptedColumns.isEmpty) return results;

    return results.map((row) {
      final decryptedRow = <String, Object?>{};

      for (final entry in row.entries) {
        if (encryptedColumns.contains(entry.key) && entry.value != null) {
          try {
            final decryptedJson = _encryptionService.decrypt(
              entry.value as String,
              _encryptionKey,
            );
            decryptedRow[entry.key] = jsonDecode(decryptedJson);
          } catch (e) {
            // If decryption fails, return original value
            decryptedRow[entry.key] = entry.value;
          }
        } else {
          decryptedRow[entry.key] = entry.value;
        }
      }

      return decryptedRow;
    }).toList();
  }

  /// Store table metadata for encrypted columns
  Future<void> _storeTableMetadata(
      String tableName, List<String> encryptedColumns) async {
    await execute('''
      CREATE TABLE IF NOT EXISTS _secure_db_metadata (
        table_name TEXT PRIMARY KEY,
        encrypted_columns TEXT
      )
    ''');

    final metadata = jsonEncode(encryptedColumns);
    await execute(
      'INSERT OR REPLACE INTO _secure_db_metadata (table_name, encrypted_columns) VALUES (?, ?)',
      [tableName, metadata],
    );
  }

  /// Remove table metadata
  Future<void> _removeTableMetadata(String tableName) async {
    await execute(
      'DELETE FROM _secure_db_metadata WHERE table_name = ?',
      [tableName],
    );
  }

  /// Get encrypted columns for a table
  Future<List<String>> getEncryptedColumns(String tableName) async {
    final results = await rawQuery(
      'SELECT encrypted_columns FROM _secure_db_metadata WHERE table_name = ?',
      [tableName],
    );

    if (results.isEmpty) return [];

    final metadata = results.first['encrypted_columns'] as String?;
    if (metadata == null) return [];

    return List<String>.from(jsonDecode(metadata));
  }
}

/// Batch operation for database transactions
class BatchOperation {
  final BatchOperationType type;
  final String table;
  final Map<String, Object?>? values;
  final String? where;
  final List<Object?>? whereArgs;
  final String? sql;
  final List<Object?>? arguments;
  final List<String> encryptedColumns;

  const BatchOperation({
    required this.type,
    required this.table,
    this.values,
    this.where,
    this.whereArgs,
    this.sql,
    this.arguments,
    this.encryptedColumns = const [],
  });

  factory BatchOperation.insert(
    String table,
    Map<String, Object?> values, {
    List<String> encryptedColumns = const [],
  }) {
    return BatchOperation(
      type: BatchOperationType.insert,
      table: table,
      values: values,
      encryptedColumns: encryptedColumns,
    );
  }

  factory BatchOperation.update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    List<String> encryptedColumns = const [],
  }) {
    return BatchOperation(
      type: BatchOperationType.update,
      table: table,
      values: values,
      where: where,
      whereArgs: whereArgs,
      encryptedColumns: encryptedColumns,
    );
  }

  factory BatchOperation.delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return BatchOperation(
      type: BatchOperationType.delete,
      table: table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  factory BatchOperation.rawQuery(
    String sql,
    List<Object?>? arguments,
  ) {
    return BatchOperation(
      type: BatchOperationType.rawInsert,
      table: '',
      sql: sql,
      arguments: arguments,
    );
  }
}

enum BatchOperationType {
  insert,
  update,
  delete,
  rawInsert,
  rawUpdate,
  rawDelete,
}
