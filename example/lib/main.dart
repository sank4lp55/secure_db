import 'package:flutter/material.dart';
import 'package:secure_db/secure_db.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SecureDB with development configuration
  await SecureDB.init(config: DbConfig.development);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureDB Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SecureDbDemo(),
    );
  }
}

class SecureDbDemo extends StatefulWidget {
  const SecureDbDemo({super.key});

  @override
  State<SecureDbDemo> createState() => _SecureDbDemoState();
}

class _SecureDbDemoState extends State<SecureDbDemo>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Hive demo data
  SecureBox<Map<String, dynamic>>? _hiveBox;
  final List<MapEntry<String, Map<String, dynamic>>> _hiveData = [];

  // SQLite demo data
  SecureDatabase? _sqliteDb;
  final List<Map<String, Object?>> _sqliteData = [];

  // Controllers
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initDatabases();
  }

  Future<void> _initDatabases() async {
    try {
      // Initialize Hive box
      _hiveBox = await SecureHive.openBox<Map<String, dynamic>>('demo_users');
      _refreshHiveData();

      // Initialize SQLite database
      _sqliteDb = await SecureSQLite.openDatabase(
        'demo_app.db',
        version: 1,
        onCreate: (db, version) async {
          await db.createTable(
            'users',
            {
              'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
              'name': 'TEXT NOT NULL',
              'email': 'TEXT UNIQUE',
              'personal_data': 'TEXT', // This will be encrypted
              'created_at': 'INTEGER',
            },
            encryptedColumns: ['personal_data'], // Encrypt sensitive data
          );
        },
      );
      _refreshSqliteData();
    } catch (e) {
      _showSnackBar('Error initializing databases: $e', isError: true);
    }
  }

  void _refreshHiveData() {
    if (_hiveBox != null) {
      setState(() {
        _hiveData.clear();
        for (final key in _hiveBox!.keys) {
          final value = _hiveBox!.get(key);
          if (value != null) {
            _hiveData.add(MapEntry(key, value));
          }
        }
      });
    }
  }

  Future<void> _refreshSqliteData() async {
    if (_sqliteDb != null) {
      try {
        final results = await _sqliteDb!.query(
          'users',
          orderBy: 'created_at DESC',
          encryptedColumns: ['personal_data'],
        );
        setState(() {
          _sqliteData.clear();
          _sqliteData.addAll(results);
        });
      } catch (e) {
        _showSnackBar('Error refreshing SQLite data: $e', isError: true);
      }
    }
  }

  Future<void> _addHiveData() async {
    final key = _keyController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (key.isEmpty || name.isEmpty || email.isEmpty) {
      _showSnackBar('Please fill in all required fields', isError: true);
      return;
    }

    try {
      await _hiveBox?.put(key, {
        'name': name,
        'email': email,
        'phone': phone,
        'created_at': DateTime.now().toIso8601String(),
        'type': 'hive_user',
      });

      _clearControllers();
      _refreshHiveData();
      _showSnackBar('User added to Hive successfully!');
    } catch (e) {
      _showSnackBar('Error adding to Hive: $e', isError: true);
    }
  }

  Future<void> _addSqliteData() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      _showSnackBar('Please fill in name and email', isError: true);
      return;
    }

    try {
      // Personal data that will be encrypted
      final personalData = jsonEncode({
        'phone': phone,
        'ssn': '123-45-6789', // Simulated sensitive data
        'address': '123 Main St, City, State',
        'notes': 'This is sensitive personal information',
      });

      await _sqliteDb?.insert(
        'users',
        {
          'name': name,
          'email': email,
          'personal_data': personalData,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        encryptedColumns: ['personal_data'],
      );

      _clearControllers();
      await _refreshSqliteData();
      _showSnackBar('User added to SQLite successfully!');
    } catch (e) {
      _showSnackBar('Error adding to SQLite: $e', isError: true);
    }
  }

  Future<void> _deleteHiveData(String key) async {
    try {
      await _hiveBox?.delete(key);
      _refreshHiveData();
      _showSnackBar('User deleted from Hive!');
    } catch (e) {
      _showSnackBar('Error deleting from Hive: $e', isError: true);
    }
  }

  Future<void> _deleteSqliteData(int id) async {
    try {
      await _sqliteDb?.delete(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );
      await _refreshSqliteData();
      _showSnackBar('User deleted from SQLite!');
    } catch (e) {
      _showSnackBar('Error deleting from SQLite: $e', isError: true);
    }
  }

  Future<void> _clearAllHiveData() async {
    try {
      await _hiveBox?.clear();
      _refreshHiveData();
      _showSnackBar('All Hive data cleared!');
    } catch (e) {
      _showSnackBar('Error clearing Hive data: $e', isError: true);
    }
  }

  Future<void> _clearAllSqliteData() async {
    try {
      await _sqliteDb?.delete('users');
      await _refreshSqliteData();
      _showSnackBar('All SQLite data cleared!');
    } catch (e) {
      _showSnackBar('Error clearing SQLite data: $e', isError: true);
    }
  }

  Future<void> _demonstrateQuickApi() async {
    try {
      // Demonstrate quick API methods
      await SecureDB.setString('demo_string', 'Hello SecureDB!');
      await SecureDB.setInt('demo_int', 42);
      await SecureDB.setBool('demo_bool', true);
      await SecureDB.setMap('demo_map', {
        'user': 'demo_user',
        'settings': {
          'theme': 'dark',
          'notifications': true,
        }
      });

      final demoString = await SecureDB.getString('demo_string');
      final demoInt = await SecureDB.getInt('demo_int');
      final demoBool = await SecureDB.getBool('demo_bool');
      final demoMap = await SecureDB.getMap('demo_map');

      _showSnackBar(
        'Quick API Demo:\n'
        'String: $demoString\n'
        'Int: $demoInt\n'
        'Bool: $demoBool\n'
        'Map: ${demoMap?['user']}',
      );
    } catch (e) {
      _showSnackBar('Error with Quick API: $e', isError: true);
    }
  }

  void _clearControllers() {
    _keyController.clear();
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SecureDB Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.storage), text: 'Hive'),
            Tab(icon: Icon(Icons.table_chart), text: 'SQLite'),
            Tab(icon: Icon(Icons.flash_on), text: 'Quick API'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHiveTab(),
          _buildSqliteTab(),
          _buildQuickApiTab(),
        ],
      ),
    );
  }

  Widget _buildHiveTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add to Hive (NoSQL)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(
                      labelText: 'Key (required)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (required)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (required)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _addHiveData,
                          child: const Text('Add to Hive'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _clearAllHiveData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Hive Data (${_hiveData.length} items)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _hiveData.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'No Hive data yet.\nAdd some users using the form above.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                )
              : Column(
                  children: _hiveData.map((entry) {
                    final data = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '${data['name']} (${entry.key})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email: ${data['email']}'),
                            if (data['phone']?.isNotEmpty == true)
                              Text('Phone: ${data['phone']}'),
                            Text('Created: ${data['created_at']}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteHiveData(entry.key),
                        ),
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 80), // Bottom padding for safe area
        ],
      ),
    );
  }

  Widget _buildSqliteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add to SQLite (SQL)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (required)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (required)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone (will be encrypted)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _addSqliteData,
                          child: const Text('Add to SQLite'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _clearAllSqliteData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'SQLite Data (${_sqliteData.length} items)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _sqliteData.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'No SQLite data yet.\nAdd some users using the form above.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                )
              : Column(
                  children: _sqliteData.map((user) {
                    Map<String, dynamic>? personalData;
                    try {
                      personalData =
                          jsonDecode(user['personal_data'] as String);
                    } catch (e) {
                      personalData = null;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '${user['name']} (ID: ${user['id']})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email: ${user['email']}'),
                            if (personalData != null) ...[
                              Text('Phone: ${personalData['phone']} 🔒'),
                              Text('SSN: ${personalData['ssn']} 🔒'),
                              Text('Address: ${personalData['address']} 🔒'),
                            ],
                            Text(
                                'Created: ${DateTime.fromMillisecondsSinceEpoch(user['created_at'] as int)}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteSqliteData(user['id'] as int),
                        ),
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 80), // Bottom padding for safe area
        ],
      ),
    );
  }

  Widget _buildQuickApiTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Quick API Demo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'The Quick API provides simple methods for common operations without needing to manage boxes or databases directly.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _demonstrateQuickApi,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run Quick API Demo'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Quick API Methods:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text('• SecureDB.setString() / getString()'),
                  const Text('• SecureDB.setInt() / getInt()'),
                  const Text('• SecureDB.setBool() / getBool()'),
                  const Text('• SecureDB.setMap() / getMap()'),
                  const Text('• SecureDB.remove()'),
                  const Text('• SecureDB.clearBox()'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Code Example:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '''// Store data
await SecureDB.setString('username', 'john');
await SecureDB.setInt('score', 100);

// Retrieve data  
String? username = await SecureDB.getString('username');
int? score = await SecureDB.getInt('score');''',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80), // Bottom padding for safe area
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keyController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
