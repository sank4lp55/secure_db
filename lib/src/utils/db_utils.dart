import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;

/// Utility functions for SecureDB operations
class DbUtils {
  const DbUtils._();

  /// Validates if a string is a valid database name
  static bool isValidDatabaseName(String name) {
    if (name.isEmpty) return false;

    // Check for invalid characters
    final invalidChars = RegExp(r'[<>:"/\\|?*\x00-\x1f]');
    if (invalidChars.hasMatch(name)) return false;

    // Check for reserved names on Windows
    final reservedNames = [
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9'
    ];
    if (reservedNames.contains(name.toUpperCase())) return false;

    return true;
  }

  /// Validates if a string is a valid box name
  static bool isValidBoxName(String name) {
    return isValidDatabaseName(name);
  }

  /// Sanitizes a database/box name
  static String sanitizeName(String name) {
    // Remove invalid characters
    String sanitized = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');

    // Ensure it doesn't start with a dot
    if (sanitized.startsWith('.')) {
      sanitized = '_$sanitized';
    }

    // Limit length
    if (sanitized.length > 255) {
      sanitized = sanitized.substring(0, 255);
    }

    return sanitized;
  }

  /// Validates JSON serializable data
  static bool isJsonSerializable(dynamic data) {
    try {
      jsonEncode(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Converts data to a JSON-serializable format
  static dynamic toJsonSerializable(dynamic data) {
    if (data == null) return null;

    if (data is String || data is num || data is bool) {
      return data;
    }

    if (data is List) {
      return data.map(toJsonSerializable).toList();
    }

    if (data is Map) {
      final result = <String, dynamic>{};
      for (final entry in data.entries) {
        result[entry.key.toString()] = toJsonSerializable(entry.value);
      }
      return result;
    }

    if (data is DateTime) {
      return data.toIso8601String();
    }

    if (data is Duration) {
      return data.inMicroseconds;
    }

    // For other types, try to convert to string
    return data.toString();
  }

  /// Converts JSON data back to appropriate types
  static dynamic fromJsonSerializable(dynamic data, Type? expectedType) {
    if (data == null) return null;

    if (expectedType == DateTime && data is String) {
      return DateTime.tryParse(data);
    }

    if (expectedType == Duration && data is int) {
      return Duration(microseconds: data);
    }

    return data;
  }

  /// Validates table name for SQL
  static bool isValidTableName(String name) {
    if (name.isEmpty) return false;

    // Must start with letter or underscore
    if (!RegExp(r'^[a-zA-Z_]').hasMatch(name)) return false;

    // Can only contain letters, numbers, and underscores
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(name)) return false;

    // Check for SQL reserved words
    final reservedWords = [
      'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'CREATE', 'DROP', 'ALTER',
      'TABLE', 'INDEX', 'VIEW', 'DATABASE', 'SCHEMA', 'TRIGGER', 'FUNCTION',
      'PROCEDURE', 'WHERE', 'FROM', 'JOIN', 'INNER', 'LEFT', 'RIGHT', 'FULL',
      'ON', 'GROUP', 'ORDER', 'BY', 'HAVING', 'UNION', 'INTERSECT', 'EXCEPT',
      'AS', 'AND', 'OR', 'NOT', 'IN', 'EXISTS', 'BETWEEN', 'LIKE', 'IS',
      'NULL', 'TRUE', 'FALSE', 'PRIMARY', 'KEY', 'FOREIGN', 'REFERENCES',
      'UNIQUE', 'CHECK', 'DEFAULT', 'AUTO_INCREMENT', 'SERIAL'
    ];

    return !reservedWords.contains(name.toUpperCase());
  }

  /// Validates column name for SQL
  static bool isValidColumnName(String name) {
    return isValidTableName(name); // Same rules apply
  }

  /// Escapes SQL identifiers
  static String escapeIdentifier(String identifier) {
    return '"${identifier.replaceAll('"', '""')}"';
  }

  /// Escapes SQL string values
  static String escapeString(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }

  /// Calculates storage size estimate for data
  static int estimateStorageSize(dynamic data) {
    if (data == null) return 0;

    if (data is String) {
      return data.length * 2; // Assuming UTF-16
    }

    if (data is int) {
      return 8; // 64-bit integer
    }

    if (data is double) {
      return 8; // 64-bit float
    }

    if (data is bool) {
      return 1;
    }

    if (data is List) {
      return data.fold<int>(0, (sum, item) => sum + estimateStorageSize(item));
    }

    if (data is Map) {
      return data.entries.fold<int>(
        0,
            (sum, entry) =>
        sum + estimateStorageSize(entry.key) + estimateStorageSize(entry.value),
      );
    }

    // For other types, use JSON encoding length
    try {
      return jsonEncode(data).length * 2;
    } catch (e) {
      return 0;
    }
  }

  /// Formats file size in human-readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Gets file size if file exists
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Creates a backup filename with timestamp
  static String createBackupFilename(String originalName) {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final extension = path.extension(originalName);
    final baseName = path.basenameWithoutExtension(originalName);
    return '${baseName}_backup_$timestamp$extension';
  }

  /// Validates encryption key format
  static bool isValidEncryptionKey(String key) {
    try {
      final decoded = base64Decode(key);
      return decoded.length >= 32; // At least 256 bits
    } catch (e) {
      return false;
    }
  }

  /// Generates a random string for testing
  static String generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
            (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// Validates migration script
  static bool isValidMigrationScript(String sql) {
    if (sql.trim().isEmpty) return false;

    // Check for dangerous operations
    final dangerousPatterns = [
      RegExp(r'\bDROP\s+DATABASE\b', caseSensitive: false),
      RegExp(r'\bDELETE\s+FROM\s+\w+\s*;?\s*$', caseSensitive: false),
      RegExp(r'\bTRUNCATE\s+TABLE\b', caseSensitive: false),
    ];

    for (final pattern in dangerousPatterns) {
      if (pattern.hasMatch(sql)) return false;
    }

    return true;
  }

  /// Parses connection string
  static Map<String, String> parseConnectionString(String connectionString) {
    final params = <String, String>{};

    for (final part in connectionString.split(';')) {
      final keyValue = part.split('=');
      if (keyValue.length == 2) {
        params[keyValue[0].trim()] = keyValue[1].trim();
      }
    }

    return params;
  }

  /// Builds connection string from parameters
  static String buildConnectionString(Map<String, String> params) {
    return params.entries.map((entry) => '${entry.key}=${entry.value}').join(';');
  }

  /// Validates database schema
  static bool isValidSchema(Map<String, dynamic> schema) {
    if (!schema.containsKey('tables')) return false;

    final tables = schema['tables'] as Map<String, dynamic>?;
    if (tables == null) return false;

    for (final tableEntry in tables.entries) {
      final tableName = tableEntry.key;
      if (!isValidTableName(tableName)) return false;

      final tableSchema = tableEntry.value as Map<String, dynamic>?;
      if (tableSchema == null || !tableSchema.containsKey('columns')) {
        return false;
      }

      final columns = tableSchema['columns'] as Map<String, dynamic>?;
      if (columns == null || columns.isEmpty) return false;

      for (final columnName in columns.keys) {
        if (!isValidColumnName(columnName)) return false;
      }
    }

    return true;
  }

  /// Deep copies a map
  static Map<String, dynamic> deepCopyMap(Map<String, dynamic> original) {
    return jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
  }

  /// Merges two maps recursively
  static Map<String, dynamic> mergeMaps(
      Map<String, dynamic> map1,
      Map<String, dynamic> map2,
      ) {
    final result = Map<String, dynamic>.from(map1);

    for (final entry in map2.entries) {
      if (result.containsKey(entry.key) &&
          result[entry.key] is Map &&
          entry.value is Map) {
        result[entry.key] = mergeMaps(
          result[entry.key] as Map<String, dynamic>,
          entry.value as Map<String, dynamic>,
        );
      } else {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// Flattens a nested map
  static Map<String, dynamic> flattenMap(
      Map<String, dynamic> map, {
        String separator = '.',
        String prefix = '',
      }) {
    final result = <String, dynamic>{};

    for (final entry in map.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix$separator${entry.key}';

      if (entry.value is Map<String, dynamic>) {
        result.addAll(
          flattenMap(
            entry.value as Map<String, dynamic>,
            separator: separator,
            prefix: key,
          ),
        );
      } else {
        result[key] = entry.value;
      }
    }

    return result;
  }

  /// Creates a simple hash of a string
  static int simpleHash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash + input.codeUnitAt(i)) & 0xffffffff;
    }
    return hash;
  }
}