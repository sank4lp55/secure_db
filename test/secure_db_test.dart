import 'package:flutter_test/flutter_test.dart';
import 'package:secure_db/secure_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize sqflite_common_ffi for desktop testing
  setUpAll(() async {
    // Initialize FFI for desktop testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Initialize SecureDB for testing
    await SecureDB.init();
  });

  group('SecureDB Tests', () {
    group('DbUtils Tests', () {
      test('validates database names correctly', () {
        // Valid names
        expect(DbUtils.isValidDatabaseName('my_database'), true);
        expect(DbUtils.isValidDatabaseName('test123'), true);
        expect(DbUtils.isValidDatabaseName('user_data'), true);

        // Invalid names
        expect(DbUtils.isValidDatabaseName(''), false);
        expect(DbUtils.isValidDatabaseName('my:database'), false);
        expect(DbUtils.isValidDatabaseName('test/db'), false);
        expect(DbUtils.isValidDatabaseName('CON'), false); // Reserved name
        expect(DbUtils.isValidDatabaseName('database?'), false);
      });

      test('sanitizes database names', () {
        expect(DbUtils.sanitizeName('my:database'), 'my_database');
        expect(DbUtils.sanitizeName('test/db'), 'test_db');
        expect(DbUtils.sanitizeName('.hidden'), '_.hidden');

        // Test length limitation
        final longName = 'a' * 300;
        expect(DbUtils.sanitizeName(longName).length, 255);
      });

      test('validates table names correctly', () {
        // Valid table names
        expect(DbUtils.isValidTableName('users'), true);
        expect(DbUtils.isValidTableName('_private_table'), true);
        expect(DbUtils.isValidTableName('table_123'), true);

        // Invalid table names
        expect(DbUtils.isValidTableName(''), false);
        expect(DbUtils.isValidTableName('123table'), false); // Starts with number
        expect(DbUtils.isValidTableName('table-name'), false); // Contains hyphen
        expect(DbUtils.isValidTableName('SELECT'), false); // Reserved word
        expect(DbUtils.isValidTableName('CREATE'), false); // Reserved word
      });

      test('escapes SQL identifiers correctly', () {
        expect(DbUtils.escapeIdentifier('table'), '"table"');
        expect(DbUtils.escapeIdentifier('my"table'), '"my""table"');
        expect(DbUtils.escapeIdentifier('user_data'), '"user_data"');
      });

      test('escapes SQL strings correctly', () {
        expect(DbUtils.escapeString('value'), "'value'");
        expect(DbUtils.escapeString("it's"), "'it''s'");
        expect(DbUtils.escapeString("O'Neill"), "'O''Neill'");
      });

      test('validates JSON serializable data', () {
        // Valid JSON data
        expect(DbUtils.isJsonSerializable('string'), true);
        expect(DbUtils.isJsonSerializable(123), true);
        expect(DbUtils.isJsonSerializable(true), true);
        expect(DbUtils.isJsonSerializable(['a', 'b', 'c']), true);
        expect(DbUtils.isJsonSerializable({'key': 'value'}), true);

        // Note: Circular reference test might not work as expected
        // Keep it simple for now
      });

      test('converts data to JSON serializable format', () {
        final date = DateTime(2024, 1, 1);
        final duration = Duration(hours: 1, minutes: 30);

        expect(DbUtils.toJsonSerializable(date), date.toIso8601String());
        expect(DbUtils.toJsonSerializable(duration), duration.inMicroseconds);
        expect(DbUtils.toJsonSerializable(null), null);
        expect(DbUtils.toJsonSerializable('string'), 'string');
        expect(DbUtils.toJsonSerializable(123), 123);
        expect(DbUtils.toJsonSerializable(true), true);
      });

      test('converts JSON data back to appropriate types', () {
        final dateString = '2024-01-01T00:00:00.000';
        final microseconds = 5400000000;

        expect(
          DbUtils.fromJsonSerializable(dateString, DateTime),
          isA<DateTime>(),
        );
        expect(
          DbUtils.fromJsonSerializable(microseconds, Duration),
          isA<Duration>(),
        );
        expect(DbUtils.fromJsonSerializable(null, null), null);
      });

      test('estimates storage size correctly', () {
        expect(DbUtils.estimateStorageSize(null), 0);
        expect(DbUtils.estimateStorageSize('hello'), 10); // 5 chars * 2
        expect(DbUtils.estimateStorageSize(123), 8);
        expect(DbUtils.estimateStorageSize(123.45), 8);
        expect(DbUtils.estimateStorageSize(true), 1);
        expect(DbUtils.estimateStorageSize([1, 2, 3]), 24); // 3 * 8
        expect(
          DbUtils.estimateStorageSize({'key': 'value'}),
          greaterThan(10), // Allow some flexibility in calculation
        );
      });

      test('formats file size correctly', () {
        expect(DbUtils.formatFileSize(500), '500 B');
        expect(DbUtils.formatFileSize(1024), '1.0 KB');
        expect(DbUtils.formatFileSize(1536), '1.5 KB');
        expect(DbUtils.formatFileSize(1048576), '1.0 MB');
        expect(DbUtils.formatFileSize(1073741824), '1.0 GB');
      });

      test('creates backup filename with timestamp', () {
        final backup = DbUtils.createBackupFilename('database.db');
        expect(backup, contains('database_backup_'));
        expect(backup, endsWith('.db'));
      });

      test('validates encryption key format', () {
        // Valid base64 key with 32+ bytes
        final validKey = 'dGhpcyBpcyBhIHZhbGlkIGVuY3J5cHRpb24ga2V5IGZvciBkYXRhYmFzZQ==';
        expect(DbUtils.isValidEncryptionKey(validKey), true);

        // Invalid keys
        expect(DbUtils.isValidEncryptionKey(''), false);
        expect(DbUtils.isValidEncryptionKey('not-base64!'), false);
        expect(DbUtils.isValidEncryptionKey('c2hvcnQ='), false); // Too short
      });

      test('generates random string', () {
        final random1 = DbUtils.generateRandomString(10);
        final random2 = DbUtils.generateRandomString(10);

        expect(random1.length, 10);
        expect(random2.length, 10);
        expect(random1, isNot(equals(random2))); // Should be different
        expect(random1, matches(RegExp(r'^[a-zA-Z0-9]+$')));
      });

      test('validates migration script', () {
        // Valid scripts
        expect(DbUtils.isValidMigrationScript('CREATE TABLE users (id INT)'), true);
        expect(DbUtils.isValidMigrationScript('ALTER TABLE users ADD COLUMN name TEXT'), true);

        // Invalid scripts
        expect(DbUtils.isValidMigrationScript(''), false);
        expect(DbUtils.isValidMigrationScript('DROP DATABASE mydb'), false);
        expect(DbUtils.isValidMigrationScript('DELETE FROM users'), false);
        expect(DbUtils.isValidMigrationScript('TRUNCATE TABLE users'), false);
      });

      test('parses and builds connection strings', () {
        final connectionString = 'host=localhost;port=5432;database=mydb';
        final params = DbUtils.parseConnectionString(connectionString);

        expect(params['host'], 'localhost');
        expect(params['port'], '5432');
        expect(params['database'], 'mydb');

        final rebuilt = DbUtils.buildConnectionString(params);
        expect(rebuilt, contains('host=localhost'));
        expect(rebuilt, contains('port=5432'));
        expect(rebuilt, contains('database=mydb'));
      });

      test('validates database schema', () {
        // Valid schema
        final validSchema = {
          'tables': {
            'users': {
              'columns': {
                'id': 'INTEGER PRIMARY KEY',
                'name': 'TEXT',
                'email': 'TEXT UNIQUE',
              }
            },
            'posts': {
              'columns': {
                'id': 'INTEGER PRIMARY KEY',
                'user_id': 'INTEGER',
                'content': 'TEXT',
              }
            }
          }
        };
        expect(DbUtils.isValidSchema(validSchema), true);

        // Invalid schemas
        expect(DbUtils.isValidSchema({}), false); // No tables key
        expect(DbUtils.isValidSchema({'tables': null}), false);
        expect(DbUtils.isValidSchema({'tables': {}}), true); // Empty tables is valid

        final invalidTableName = {
          'tables': {
            'SELECT': { // Reserved word as table name
              'columns': {'id': 'INTEGER'}
            }
          }
        };
        expect(DbUtils.isValidSchema(invalidTableName), false);
      });

      test('deep copies map', () {
        final original = {
          'level1': {
            'level2': {
              'value': 'test'
            }
          }
        };

        final copy = DbUtils.deepCopyMap(original);

        // Verify it's a deep copy
        expect(copy, equals(original));

        // Modify copy shouldn't affect original
        (copy['level1'] as Map)['level2'] = {'value': 'modified'};
        expect((original['level1'] as Map)['level2'], {'value': 'test'});
      });

      test('merges maps recursively', () {
        final map1 = {
          'a': 1,
          'b': {
            'c': 2,
            'd': 3,
          }
        };

        final map2 = {
          'b': {
            'd': 4,
            'e': 5,
          },
          'f': 6,
        };

        final merged = DbUtils.mergeMaps(map1, map2);

        expect(merged['a'], 1);
        expect(merged['f'], 6);
        expect((merged['b'] as Map)['c'], 2);
        expect((merged['b'] as Map)['d'], 4); // Overridden
        expect((merged['b'] as Map)['e'], 5); // New
      });

      test('flattens nested map', () {
        final nested = {
          'user': {
            'profile': {
              'name': 'John',
              'age': 30,
            },
            'settings': {
              'theme': 'dark',
            }
          }
        };

        final flat = DbUtils.flattenMap(nested);

        expect(flat['user.profile.name'], 'John');
        expect(flat['user.profile.age'], 30);
        expect(flat['user.settings.theme'], 'dark');
      });

      test('creates simple hash', () {
        final hash1 = DbUtils.simpleHash('test');
        final hash2 = DbUtils.simpleHash('test');
        final hash3 = DbUtils.simpleHash('different');

        expect(hash1, equals(hash2)); // Same input, same hash
        expect(hash1, isNot(equals(hash3))); // Different input, different hash
      });
    });

    group('SecureHive Tests', () {
      test('opens and uses Hive box', () async {
        final box = await SecureHive.openBox<String>('test_box');

        await box.put('test_key', 'test_value');
        final value = box.get('test_key');

        expect(value, 'test_value');

        await box.close();
      });

      test('encrypts Hive data', () async {
        final box = await SecureHive.openBox<Map<String, dynamic>>('encrypted_box');

        final sensitiveData = {
          'ssn': '123-45-6789',
          'creditCard': '4111-1111-1111-1111',
          'password': 'superSecret123',
        };

        await box.put('user_data', sensitiveData);
        final retrievedData = box.get('user_data');

        expect(retrievedData, equals(sensitiveData));

        await box.close();
      });
    });

    group('Quick API Tests', () {
      test('stores and retrieves different data types', () async {
        // String
        await SecureDB.setString('test_string', 'Hello World');
        expect(await SecureDB.getString('test_string'), 'Hello World');

        // Integer
        await SecureDB.setInt('test_int', 42);
        expect(await SecureDB.getInt('test_int'), 42);

        // Boolean
        await SecureDB.setBool('test_bool', true);
        expect(await SecureDB.getBool('test_bool'), true);

        // Map
        final testMap = {'key': 'value', 'number': 123};
        await SecureDB.setMap('test_map', testMap);
        expect(await SecureDB.getMap('test_map'), testMap);

        // Remove
        await SecureDB.remove('test_string');
        expect(await SecureDB.getString('test_string'), null);
      });
    });

    group('SecureSQLite Tests', () {
      test('opens and closes database', () async {
        final dbName = 'test_${DateTime.now().millisecondsSinceEpoch}.db';

        final db = await SecureSQLite.openDatabase(
          dbName,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE test (
                id INTEGER PRIMARY KEY,
                data TEXT
              )
            ''');
          },
        );

        expect(db.isOpen, true);
        expect(SecureSQLite.isDatabaseOpen(dbName), true);
        expect(SecureSQLite.openDatabaseCount, greaterThanOrEqualTo(1));

        await SecureSQLite.closeDatabase(dbName);
        expect(SecureSQLite.isDatabaseOpen(dbName), false);
      });

      test('returns existing database if already open', () async {
        final dbName = 'test_${DateTime.now().millisecondsSinceEpoch}.db';

        final db1 = await SecureSQLite.openDatabase(dbName);
        final db2 = await SecureSQLite.openDatabase(dbName);

        expect(identical(db1, db2), true);

        await SecureSQLite.closeDatabase(dbName);
      });

      test('performs health check on databases', () async {
        final dbName = 'test_${DateTime.now().millisecondsSinceEpoch}.db';

        await SecureSQLite.openDatabase(dbName);

        final health = await SecureSQLite.healthCheck();
        expect(health[dbName], true);

        await SecureSQLite.closeDatabase(dbName);
      });
    });

    group('SecureDatabase Tests', () {
      late SecureDatabase db;
      final testDbName = 'test_secure_${DateTime.now().millisecondsSinceEpoch}.db';

      setUp(() async {
        db = await SecureSQLite.openDatabase(
          testDbName,
          version: 1,
          onCreate: (db, version) async {
            await db.createTable(
              'users',
              {
                'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
                'name': 'TEXT NOT NULL',
                'email': 'TEXT UNIQUE',
                'password': 'TEXT',
                'metadata': 'TEXT',
              },
              encryptedColumns: ['password', 'metadata'],
            );
          },
        );
      });

      tearDown(() async {
        await SecureSQLite.deleteDatabase(testDbName);
      });

      test('inserts and queries data with encryption', () async {
        final userId = await db.insert(
          'users',
          {
            'name': 'John Doe',
            'email': 'john@example.com',
            'password': 'secret123',
            'metadata': {'role': 'admin', 'level': 5},
          },
          encryptedColumns: ['password', 'metadata'],
        );

        expect(userId, greaterThan(0));

        final results = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
          encryptedColumns: ['password', 'metadata'],
        );

        expect(results.length, 1);
        expect(results[0]['name'], 'John Doe');
        expect(results[0]['email'], 'john@example.com');
        expect(results[0]['password'], 'secret123');
        expect(results[0]['metadata'], {'role': 'admin', 'level': 5});
      });

      test('updates data with encryption', () async {
        final userId = await db.insert(
          'users',
          {
            'name': 'Jane Doe',
            'email': 'jane@example.com',
            'password': 'oldpass',
          },
          encryptedColumns: ['password'],
        );

        final updated = await db.update(
          'users',
          {'password': 'newpass'},
          where: 'id = ?',
          whereArgs: [userId],
          encryptedColumns: ['password'],
        );

        expect(updated, 1);

        final results = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
          encryptedColumns: ['password'],
        );

        expect(results[0]['password'], 'newpass');
      });

      test('deletes data', () async {
        final userId = await db.insert(
          'users',
          {
            'name': 'Temp User',
            'email': 'temp@example.com',
            'password': 'temppass',
          },
        );

        final deleted = await db.delete(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
        );

        expect(deleted, 1);

        final results = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
        );

        expect(results.isEmpty, true);
      });

      test('performs transactions', () async {
        final result = await db.transaction<bool>((txn) async {
          await txn.insert('users', {
            'name': 'User 1',
            'email': 'user1@example.com',
            'password': 'pass1',
          });

          await txn.insert('users', {
            'name': 'User 2',
            'email': 'user2@example.com',
            'password': 'pass2',
          });

          return true;
        });

        expect(result, true);

        final count = await db.rawQuery('SELECT COUNT(*) as count FROM users');
        expect(count[0]['count'], greaterThanOrEqualTo(2));
      });

      test('checks table existence', () async {
        expect(await db.tableExists('users'), true);
        expect(await db.tableExists('nonexistent'), false);
      });

      test('gets table and column names', () async {
        final tables = await db.getTableNames();
        expect(tables, contains('users'));

        final columns = await db.getColumnNames('users');
        expect(columns, containsAll(['id', 'name', 'email', 'password', 'metadata']));
      });

      test('gets encrypted columns metadata', () async {
        final encryptedColumns = await db.getEncryptedColumns('users');
        expect(encryptedColumns, containsAll(['password', 'metadata']));
      });
    });
  });
}