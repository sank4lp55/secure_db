/// Base exception for SecureDB operations
abstract class SecureDbException implements Exception {
  final String message;
  final dynamic cause;
  final StackTrace? stackTrace;

  const SecureDbException(this.message, [this.cause, this.stackTrace]);

  @override
  String toString() => 'SecureDbException: $message';
}

/// Exception thrown when encryption/decryption fails
class EncryptionException extends SecureDbException {
  const EncryptionException(super.message, [super.cause, super.stackTrace]);

  @override
  String toString() => 'EncryptionException: $message';
}

/// Exception thrown when database operations fail
class DatabaseException extends SecureDbException {
  const DatabaseException(super.message, [super.cause, super.stackTrace]);

  @override
  String toString() => 'DatabaseException: $message';
}

/// Exception thrown when box operations fail
class BoxException extends SecureDbException {
  final String boxName;

  const BoxException(this.boxName, super.message, [super.cause, super.stackTrace]);

  @override
  String toString() => 'BoxException[$boxName]: $message';
}

/// Exception thrown when key management fails
class KeyManagementException extends SecureDbException {
  const KeyManagementException(super.message, [super.cause, super.stackTrace]);

  @override
  String toString() => 'KeyManagementException: $message';
}

/// Exception thrown when initialization fails
class InitializationException extends SecureDbException {
  const InitializationException(super.message, [super.cause, super.stackTrace]);

  @override
  String toString() => 'InitializationException: $message';
}

/// Exception thrown when configuration is invalid
class ConfigurationException extends SecureDbException {
  const ConfigurationException(super.message, [super.cause, super.stackTrace]);

  @override
  String toString() => 'ConfigurationException: $message';
}

/// Exception thrown when migration fails
class MigrationException extends SecureDbException {
  final int fromVersion;
  final int toVersion;

  const MigrationException(
      this.fromVersion,
      this.toVersion,
      super.message, [
        super.cause,
        super.stackTrace,
      ]);

  @override
  String toString() => 'MigrationException[$fromVersion->$toVersion]: $message';
}

/// Exception thrown when transaction operations fail
class TransactionException extends SecureDbException {
  const TransactionException(super.message, [super.cause, super.stackTrace]);

  @override
  String toString() => 'TransactionException: $message';
}

/// Exception thrown when validation fails
class ValidationException extends SecureDbException {
  final String field;

  const ValidationException(this.field, super.message, [super.cause, super.stackTrace]);

  @override
  String toString() => 'ValidationException[$field]: $message';
}

/// Exception thrown when operations are performed on closed databases
class ClosedDatabaseException extends SecureDbException {
  final String databaseName;

  const ClosedDatabaseException(this.databaseName)
      : super('Database "$databaseName" is closed');

  @override
  String toString() => 'ClosedDatabaseException: Database "$databaseName" is closed';
}

/// Exception thrown when trying to access non-existent resources
class NotFoundException extends SecureDbException {
  final String resourceType;
  final String resourceName;

  const NotFoundException(this.resourceType, this.resourceName)
      : super('$resourceType "$resourceName" not found');

  @override
  String toString() => 'NotFoundException: $resourceType "$resourceName" not found';
}

/// Exception thrown when operations are not supported
class UnsupportedOperationException extends SecureDbException {
  const UnsupportedOperationException(super.message, [super.cause, super.stackTrace]);

  @override
  String toString() => 'UnsupportedOperationException: $message';
}

/// Exception thrown when concurrent access issues occur
class ConcurrencyException extends SecureDbException {
  const ConcurrencyException(super.message, [super.cause, super.stackTrace]);

  @override
  String toString() => 'ConcurrencyException: $message';
}

/// Helper class for creating common exceptions
class SecureDbExceptions {
  const SecureDbExceptions._();

  static EncryptionException encryptionFailed(String operation, [dynamic cause]) {
    return EncryptionException(
      'Failed to $operation data',
      cause,
      StackTrace.current,
    );
  }

  static DatabaseException databaseOperationFailed(String operation, [dynamic cause]) {
    return DatabaseException(
      'Database operation failed: $operation',
      cause,
      StackTrace.current,
    );
  }

  static BoxException boxOperationFailed(String boxName, String operation, [dynamic cause]) {
    return BoxException(
      boxName,
      'Box operation failed: $operation',
      cause,
      StackTrace.current,
    );
  }

  static KeyManagementException keyNotFound(String keyName) {
    return KeyManagementException(
      'Encryption key "$keyName" not found',
      null,
      StackTrace.current,
    );
  }

  static InitializationException initializationFailed(String component, [dynamic cause]) {
    return InitializationException(
      'Failed to initialize $component',
      cause,
      StackTrace.current,
    );
  }

  static ConfigurationException invalidConfiguration(String reason) {
    return ConfigurationException(
      'Invalid configuration: $reason',
      null,
      StackTrace.current,
    );
  }

  static MigrationException migrationFailed(int fromVersion, int toVersion, [dynamic cause]) {
    return MigrationException(
      fromVersion,
      toVersion,
      'Database migration failed',
      cause,
      StackTrace.current,
    );
  }

  static TransactionException transactionFailed(String reason, [dynamic cause]) {
    return TransactionException(
      'Transaction failed: $reason',
      cause,
      StackTrace.current,
    );
  }

  static ValidationException invalidData(String field, String reason) {
    return ValidationException(
      field,
      'Invalid data for field "$field": $reason',
      null,
      StackTrace.current,
    );
  }

  static ClosedDatabaseException databaseClosed(String databaseName) {
    return ClosedDatabaseException(databaseName);
  }

  static NotFoundException notFound(String resourceType, String resourceName) {
    return NotFoundException(resourceType, resourceName);
  }

  static UnsupportedOperationException unsupportedOperation(String operation) {
    return UnsupportedOperationException(
      'Operation not supported: $operation',
      null,
      StackTrace.current,
    );
  }

  static ConcurrencyException concurrencyIssue(String reason) {
    return ConcurrencyException(
      'Concurrency issue: $reason',
      null,
      StackTrace.current,
    );
  }
}