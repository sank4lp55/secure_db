import 'package:flutter_test/flutter_test.dart';
import 'package:secure_db/secure_db.dart';

void main() {
  group('SecureDB', () {
    test('exports are accessible', () {
      // Test that the main exports are accessible
      expect(SecureDB, isNotNull);
      expect(SecureHive, isNotNull);
      expect(SecureSQLite, isNotNull);
      expect(DbConfig, isNotNull);
    });

    test('DbConfig has expected values', () {
      expect(DbConfig.development, isNotNull);
      expect(DbConfig.production, isNotNull);
      expect(DbConfig.testing, isNotNull);
    });
  });
}
