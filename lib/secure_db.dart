library secure_db;

// Core interfaces
export 'src/core/secure_db_interface.dart';
export 'src/core/encryption_service.dart';
export 'src/core/db_config.dart';

// Hive implementation
export 'src/hive/secure_hive.dart';
export 'src/hive/secure_box.dart';

// SQLite implementation
export 'src/sqlite/secure_sqlite.dart';
export 'src/sqlite/secure_database.dart';

// Models and exceptions
export 'src/models/query_result.dart';
export 'src/models/db_exceptions.dart';

// Utilities
export 'src/utils/db_utils.dart';
