/// Configuration class for SecureDB
class DbConfig {
  /// Directory path for database files
  final String? databasePath;

  /// Default encryption key (optional)
  final String? defaultEncryptionKey;

  /// Whether to enable debug logging
  final bool enableLogging;

  /// Database version for SQLite
  final int version;

  /// Whether to enable WAL mode for SQLite
  final bool enableWalMode;

  /// Maximum number of database connections
  final int maxConnections;

  const DbConfig({
    this.databasePath,
    this.defaultEncryptionKey,
    this.enableLogging = false,
    this.version = 1,
    this.enableWalMode = true,
    this.maxConnections = 1,
  });

  /// Default configuration
  static const DbConfig defaultConfig = DbConfig();

  /// Development configuration with logging enabled
  static const DbConfig development = DbConfig(
    enableLogging: true,
  );

  /// Production configuration
  static const DbConfig production = DbConfig(
    enableLogging: false,
    enableWalMode: true,
  );

  /// Copy configuration with updated values
  DbConfig copyWith({
    String? databasePath,
    String? defaultEncryptionKey,
    bool? enableLogging,
    int? version,
    bool? enableWalMode,
    int? maxConnections,
  }) {
    return DbConfig(
      databasePath: databasePath ?? this.databasePath,
      defaultEncryptionKey: defaultEncryptionKey ?? this.defaultEncryptionKey,
      enableLogging: enableLogging ?? this.enableLogging,
      version: version ?? this.version,
      enableWalMode: enableWalMode ?? this.enableWalMode,
      maxConnections: maxConnections ?? this.maxConnections,
    );
  }

  @override
  String toString() {
    return 'DbConfig('
        'databasePath: $databasePath, '
        'enableLogging: $enableLogging, '
        'version: $version, '
        'enableWalMode: $enableWalMode, '
        'maxConnections: $maxConnections'
        ')';
  }
}
