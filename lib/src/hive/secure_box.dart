import 'dart:convert';
import 'package:hive/hive.dart';
import '../core/encryption_service.dart';

/// A secure wrapper around Hive box that provides automatic encryption/decryption
class SecureBox<T> {
  final Box<String> _box;
  final EncryptionService _encryptionService;
  final String _encryptionKey;

  SecureBox(this._box, this._encryptionService, this._encryptionKey);

  /// Gets a value by key, automatically decrypting it
  T? get(dynamic key) {
    final encryptedValue = _box.get(key.toString());
    if (encryptedValue == null) return null;

    try {
      final decryptedJson = _encryptionService.decrypt(encryptedValue, _encryptionKey);
      final decodedValue = jsonDecode(decryptedJson);
      return decodedValue as T;
    } catch (e) {
      throw Exception('Failed to decrypt value for key "$key": $e');
    }
  }

  /// Puts a value with automatic encryption
  Future<void> put(dynamic key, T value) async {
    try {
      final jsonValue = jsonEncode(value);
      final encryptedValue = _encryptionService.encrypt(jsonValue, _encryptionKey);
      await _box.put(key.toString(), encryptedValue);
    } catch (e) {
      throw Exception('Failed to encrypt and store value for key "$key": $e');
    }
  }

  /// Deletes a key-value pair
  Future<void> delete(dynamic key) async {
    await _box.delete(key.toString());
  }

  /// Checks if a key exists
  bool containsKey(dynamic key) {
    return _box.containsKey(key.toString());
  }

  /// Gets all keys
  Iterable<String> get keys => _box.keys.cast<String>();

  /// Gets all values (decrypted)
  Iterable<T> get values {
    return _box.values.map((encryptedValue) {
      try {
        final decryptedJson = _encryptionService.decrypt(encryptedValue, _encryptionKey);
        final decodedValue = jsonDecode(decryptedJson);
        return decodedValue as T;
      } catch (e) {
        throw Exception('Failed to decrypt value: $e');
      }
    });
  }

  /// Gets the number of key-value pairs
  int get length => _box.length;

  /// Checks if the box is empty
  bool get isEmpty => _box.isEmpty;

  /// Checks if the box is not empty
  bool get isNotEmpty => _box.isNotEmpty;

  /// Gets the name of the box
  String get name => _box.name;

  /// Checks if the box is open
  bool get isOpen => _box.isOpen;

  /// Clears all data in the box
  Future<void> clear() async {
    await _box.clear();
  }

  /// Closes the box
  Future<void> close() async {
    await _box.close();
  }

  /// Compacts the box (removes deleted entries)
  Future<void> compact() async {
    await _box.compact();
  }

  /// Gets all entries as a Map (decrypted)
  Map<String, T> toMap() {
    final Map<String, T> result = {};
    for (final key in keys) {
      final value = get(key);
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  /// Stream of box changes
  Stream<BoxEvent> watch({dynamic key}) {
    return _box.watch(key: key?.toString());
  }

  /// Gets multiple values at once
  Map<String, T?> getAll(Iterable<String> keys) {
    final Map<String, T?> result = {};
    for (final key in keys) {
      result[key] = get(key);
    }
    return result;
  }

  /// Puts multiple values at once
  Future<void> putAll(Map<String, T> entries) async {
    for (final entry in entries.entries) {
      await put(entry.key, entry.value);
    }
  }

  /// Deletes multiple keys at once
  Future<void> deleteAll(Iterable<String> keys) async {
    for (final key in keys) {
      await delete(key);
    }
  }

  /// Gets a value with a default fallback
  T getWithDefault(dynamic key, T defaultValue) {
    return get(key) ?? defaultValue;
  }

  /// Puts a value only if the key doesn't exist
  Future<bool> putIfAbsent(dynamic key, T value) async {
    if (!containsKey(key)) {
      await put(key, value);
      return true;
    }
    return false;
  }

  /// Updates a value using a function
  Future<void> update(dynamic key, T Function(T? current) updater) async {
    final current = get(key);
    final updated = updater(current);
    await put(key, updated);
  }

  /// Gets the first key-value pair that matches a condition
  MapEntry<String, T>? firstWhere(bool Function(String key, T value) test) {
    for (final key in keys) {
      final value = get(key);
      if (value != null && test(key, value)) {
        return MapEntry(key, value);
      }
    }
    return null;
  }

  /// Filters entries based on a condition
  Map<String, T> where(bool Function(String key, T value) test) {
    final Map<String, T> result = {};
    for (final key in keys) {
      final value = get(key);
      if (value != null && test(key, value)) {
        result[key] = value;
      }
    }
    return result;
  }

  /// Gets entries as a list of MapEntry objects
  List<MapEntry<String, T>> get entries {
    final List<MapEntry<String, T>> result = [];
    for (final key in keys) {
      final value = get(key);
      if (value != null) {
        result.add(MapEntry(key, value));
      }
    }
    return result;
  }

  /// Adds a value to the box (similar to put but follows List conventions)
  Future<void> add(T value) async {
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    await put(key, value);
  }

  /// Iterates over all key-value pairs
  void forEach(void Function(String key, T value) action) {
    for (final key in keys) {
      final value = get(key);
      if (value != null) {
        action(key, value);
      }
    }
  }
}