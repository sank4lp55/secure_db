# SecureDB

A unified secure database package for Flutter that provides encrypted storage using both **Hive** and **SQLite** with automatic encryption/decryption. Choose the storage solution that fits your needs while maintaining consistent security across your app.

## 🚀 Features

- 🔐 **Dual Storage Options**: Support for both Hive (NoSQL) and SQLite (SQL)
- 🛡️ **Automatic Encryption**: All data encrypted with AES-256-GCM before storage
- 🔑 **Secure Key Management**: Platform-specific secure storage (Keychain/Keystore)
- 🎯 **Type Safety**: Full generic type support for both storage systems
- 🔄 **Easy Migration**: Simple migration from existing Hive or SQLite implementations
- 📱 **Cross-Platform**: Works on iOS, Android, macOS, Windows, and Linux
- ⚡ **Performance**: Optimized for both small key-value pairs and complex queries
- 🛠️ **Developer Friendly**: Intuitive APIs that mirror native Hive and SQLite

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  secure_db: ^1.0.3
```

Then run:

```bash
flutter pub get
```

## 🏁 Quick Start

### Initialize SecureDB

```dart
import 'package:secure_db/secure_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SecureDB with both Hive and SQLite support
  await SecureDB.init();

  runApp(MyApp());
}
```

### Simple Key-Value Storage (Quick API)

```dart
// Store different types of data
await SecureDB.setString('username', 'john_doe');
await SecureDB.setInt('user_id', 12345);
await SecureDB.setBool('is_premium', true);
await SecureDB.setMap('user_profile', {
'name': 'John Doe',
'email': 'john@example.com',
'preferences': {'theme': 'dark'}
});

// Retrieve data
String? username = await SecureDB.getString('username');
int? userId = await SecureDB.getInt('user_id');
bool? isPremium = await SecureDB.getBool('is_premium');
Map<String, dynamic>? profile = await SecureDB.getMap('user_profile');

print('User: $username ($userId) - Premium: $isPremium');
```

## 📚 Usage Guide

### 🗃️ Hive Storage (NoSQL)

Perfect for simple key-value storage, user preferences, and small datasets.

```dart
// Method 1: Through SecureDB factory (recommended)
final userBox = await SecureDB.hive().openBox<Map<String, dynamic>>('users');

// Method 2: Direct instance access
final userBox = await SecureHive.instance.openBox<Map<String, dynamic>>('users');

// Store user data with automatic encryption
await userBox.put('user_123', {
'name': 'John Doe',
'email': 'john@example.com',
'created_at': DateTime.now().toIso8601String(),
'settings': {
'theme': 'dark',
'notifications': true,
}
});

// Retrieve user data (automatically decrypted)
Map<String, dynamic>? user = userBox.get('user_123');
print('User: ${user?['name']}');

// Batch operations
await userBox.putAll({
'user_124': {'name': 'Jane Smith', 'email': 'jane@example.com'},
'user_125': {'name': 'Bob Wilson', 'email': 'bob@example.com'},
});

// Listen to changes
userBox.watch().listen((BoxEvent event) {
print('User ${event.key} was ${event.deleted ? 'deleted' : 'updated'}');
});

// Additional operations via instance
await SecureHive.instance.closeBox('users');
await SecureHive.instance.deleteBox('users');
bool exists = await SecureHive.instance.boxExists('users');
```

### 🗄️ SQLite Storage (SQL)

Ideal for complex data relationships, queries, and larger datasets.

```dart
// Method 1: Through SecureDB factory (recommended)
final db = await SecureDB.sqlite().openDatabase(
  'app_database.db',
  version: 1,
  onCreate: (db, version) async {
    // Create tables with encrypted columns
    await db.createTable(
      'users',
      {
        'id': 'INTEGER PRIMARY KEY',
        'email': 'TEXT UNIQUE',
        'profile_data': 'TEXT',  // This will be encrypted
        'created_at': 'INTEGER',
      },
      encryptedColumns: ['profile_data'], // Specify which columns to encrypt
    );
  },
);

// Method 2: Direct instance access
final db = await SecureSQLite.instance.openDatabase(
  'app_database.db',
  version: 1,
  onCreate: (db, version) async {
    // Same configuration as above
  },
);

// Insert encrypted data
await db.insert(
  'users',
  {
    'email': 'john@example.com',
    'profile_data': jsonEncode({
      'name': 'John Doe',
      'phone': '+1234567890',
      'ssn': '123-45-6789',  // Sensitive data automatically encrypted
    }),
    'created_at': DateTime.now().millisecondsSinceEpoch,
  },
  encryptedColumns: ['profile_data'],
);

// Query with automatic decryption
final users = await db.query(
  'users',
  where: 'email = ?',
  whereArgs: ['john@example.com'],
  encryptedColumns: ['profile_data'],
);

for (final user in users) {
  print('User: ${user['email']}');
  final profileData = jsonDecode(user['profile_data'] as String);
  print('Name: ${profileData['name']}');
}

// Additional operations via instance
await SecureSQLite.instance.closeDatabase('app_database.db');
await SecureSQLite.instance.deleteDatabase('app_database.db');
bool exists = await SecureSQLite.instance.databaseExists('app_database.db');
```

### 🔄 Advanced SQLite Operations

```dart
// Complex queries with joins
final result = await db.rawQuery('''
  SELECT u.email, p.title, p.content
  FROM users u
  JOIN posts p ON u.id = p.user_id
  WHERE u.created_at > ?
  ORDER BY p.created_at DESC
  LIMIT 10
''', [DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch]);

// Transactions for data integrity
await db.transaction((txn) async {
  await txn.insert('users', userData, encryptedColumns: ['profile_data']);
  await txn.insert('user_settings', settingsData, encryptedColumns: ['preferences']);
  await txn.insert('audit_log', logData);
});

// Batch operations for performance
await db.batch([
  BatchOperation.insert('posts', post1Data, encryptedColumns: ['content']),
  BatchOperation.insert('posts', post2Data, encryptedColumns: ['content']),
  BatchOperation.update('users', updateData, where: 'id = ?', whereArgs: [userId]),
]);
```

### 🔧 Configuration

```dart
// Custom configuration
await SecureDB.init(config: DbConfig(
  enableLogging: true,
  databasePath: '/custom/path',
  enableWalMode: true,
  maxConnections: 5,
));

// Development vs Production
await SecureDB.init(config: DbConfig.development); // Enables logging
await SecureDB.init(config: DbConfig.production);  // Optimized for production
```

### 🔐 Custom Encryption Keys

```dart
// Use your own encryption key
final customKey = 'your-base64-encoded-256-bit-key';

// For Hive
final box = await SecureDB.hive().openBox<String>(
  'secure_box',
  encryptionKey: customKey,
);

// Or via instance
final box = await SecureHive.instance.openBox<String>(
  'secure_box',
  encryptionKey: customKey,
);

// For SQLite
final db = await SecureDB.sqlite().openDatabase(
  'secure_db.db',
  encryptionKey: customKey,
);

// Or via instance
final db = await SecureSQLite.instance.openDatabase(
  'secure_db.db',
  encryptionKey: customKey,
);
```

## 🎯 When to Use What

### Use **Hive** when:
- ✅ Simple key-value storage
- ✅ User preferences and settings
- ✅ Caching data
- ✅ Small to medium datasets
- ✅ Rapid prototyping
- ✅ Offline-first apps with simple data

### Use **SQLite** when:
- ✅ Complex data relationships
- ✅ Advanced queries with joins, aggregations
- ✅ Large datasets
- ✅ Data integrity requirements
- ✅ Reporting and analytics
- ✅ Existing SQL knowledge in team

## 📊 API Reference

### SecureDB (Main Interface)

#### Quick Access Methods
- `setString(key, value)` / `getString(key)` - String storage
- `setInt(key, value)` / `getInt(key)` - Integer storage
- `setBool(key, value)` / `getBool(key)` - Boolean storage
- `setMap(key, value)` / `getMap(key)` - Map storage
- `remove(key)` - Remove key
- `clearBox(boxName)` - Clear all data in box
- `closeAll()` - Close all databases

#### Factory Methods
- `SecureDB.hive()` - Returns SecureHive instance
- `SecureDB.sqlite()` - Returns SecureSQLite instance
- `SecureDB.init(config)` - Initialize with configuration

### SecureHive

Access via `SecureDB.hive()` or `SecureHive.instance`:

- `openBox<T>(name, {encryptionKey})` - Open encrypted Hive box
- `closeBox(name)` - Close specific box
- `deleteBox(name)` - Delete box and encryption key
- `boxExists(name)` - Check if box exists
- `getOpenBoxNames()` - List open boxes
- `closeAllBoxes()` - Close all open boxes
- `compactAll()` - Compact all open boxes
- `getBoxSize(name)` - Get estimated box size

### SecureBox<T>

#### Core Operations
- `get(key)` / `put(key, value)` - Basic storage
- `delete(key)` / `containsKey(key)` - Key management
- `clear()` / `close()` - Box management

#### Batch Operations
- `putAll(Map<String, T>)` - Store multiple values
- `getAll(List<String>)` - Get multiple values
- `deleteAll(List<String>)` - Delete multiple keys

#### Advanced Features
- `watch({key})` - Listen to changes
- `toMap()` - Convert to Map
- `where(predicate)` - Filter entries
- `update(key, updater)` - Update with function

### SecureSQLite

Access via `SecureDB.sqlite()` or `SecureSQLite.instance`:

- `openDatabase(name, {version, onCreate, onUpgrade, encryptionKey})` - Open database
- `closeDatabase(name)` - Close specific database
- `deleteDatabase(name)` - Delete database file
- `databaseExists(name)` - Check if database exists
- `closeAll()` - Close all databases
- `getOpenDatabases()` - List open databases
- `vacuumAll()` - Vacuum all databases
- `optimizeAll()` - Optimize all databases
- `enableWalMode()` - Enable WAL mode

### SecureDatabase

#### Core SQL Operations
- `execute(sql, [args])` - Execute SQL command
- `rawQuery(sql, [args])` - Raw SELECT query
- `insert(table, values, {encryptedColumns})` - Insert with encryption
- `update(table, values, {where, encryptedColumns})` - Update with encryption
- `query(table, {where, encryptedColumns})` - Query with decryption
- `delete(table, {where})` - Delete records

#### Advanced Features
- `transaction(action)` - Execute in transaction
- `batch(operations)` - Batch operations
- `createTable(name, columns, {encryptedColumns})` - Create table with encryption
- `insertOrUpdate(table, values, {conflictColumns})` - UPSERT operation

## 🔒 Security Features

### Encryption
- **Algorithm**: AES-256-GCM for authenticated encryption
- **Key Generation**: Cryptographically secure random keys (256-bit)
- **IV**: Unique initialization vector for each encryption operation
- **Key Storage**: Platform-specific secure storage (iOS Keychain, Android Keystore)

### Key Management
- Automatic key generation per database/box
- Secure key storage using platform APIs
- Key rotation support (manual)
- Custom key support for advanced use cases

### Data Protection
- All sensitive data encrypted before storage
- No plaintext data written to disk
- Configurable column-level encryption for SQLite
- Automatic encryption/decryption transparent to developer

## 🔄 Migration Guide

### From Hive

```dart
// Before (regular Hive)
final box = await Hive.openBox('myBox');
await box.put('key', 'value');
String? value = box.get('key');

// After (SecureDB)
final box = await SecureDB.hive().openBox<String>('myBox');
// Or: final box = await SecureHive.instance.openBox<String>('myBox');
await box.put('key', 'value');
String? value = box.get('key');
// All other operations remain the same!
```

### From SQLite

```dart
// Before (regular sqflite)
final db = await openDatabase('mydb.db');
await db.insert('users', {'name': 'John'});

// After (SecureDB)
final db = await SecureDB.sqlite().openDatabase('mydb.db');
// Or: final db = await SecureSQLite.instance.openDatabase('mydb.db');
await db.insert('users', {'name': 'John'}, encryptedColumns: ['sensitive_field']);
// Most operations remain the same, just add encryptedColumns when needed!
```

## ⚡ Performance Tips

1. **Batch Operations**: Use `putAll`, `getAll`, and batch operations for multiple items
2. **Transactions**: Wrap multiple SQLite operations in transactions
3. **Selective Encryption**: Only encrypt sensitive columns in SQLite
4. **Connection Pooling**: Reuse database connections
5. **Lazy Loading**: Don't load all data at once, use pagination
6. **Proper Indexing**: Create indexes on frequently queried columns

## 🧪 Testing

```dart
// Test helper for encrypted data
import 'package:secure_db/secure_db.dart';

void main() {
  group('SecureDB Tests', () {
    setUpAll(() async {
      await SecureDB.init();
    });

    test('should encrypt and decrypt data', () async {
      final box = await SecureDB.hive().openBox<String>('test');
      await box.put('test_key', 'sensitive_data');
      
      final retrieved = box.get('test_key');
      expect(retrieved, equals('sensitive_data'));
    });

    tearDownAll(() async {
      await SecureDB.closeAll();
    });
  });
}
```

## 🤝 Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) and submit pull requests to our repository.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆕 Changelog

### 1.0.3
- Improved API consistency with instance-based access pattern
- Enhanced singleton implementation for both Hive and SQLite
- Better support for both factory and direct instance access methods
- Updated documentation with comprehensive usage examples

### 1.0.1
- Fixed static analysis issues for improved code quality
- Removed debug print statements for cleaner production code
- Enhanced documentation with dual access method examples

### 1.0.0
- Initial release with Hive and SQLite support
- AES-256-GCM encryption for all data
- Platform-specific secure key storage
- Comprehensive API for both storage types
- Transaction and batch operation support
- Full documentation and examples

## 🔗 Links

- [Package on pub.dev](https://pub.dev/packages/secure_db)
- [GitHub Repository](https://github.com/sank4lp55/secure_db)
- [Issue Tracker](https://github.com/sank4lp55/secure_db/issues)
- [Documentation](https://github.com/sank4lp55/secure_db/wiki)