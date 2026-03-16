## 1.0.6

* **SECURITY FIX**: Fixed critical security vulnerability in fallback key generation
  * Replaced weak `Random(hashCode)` implementation with PBKDF2-like key derivation using 100,000 SHA-256 iterations
  * Fallback keys are now cryptographically strong and resistant to brute-force attacks
  * Added warning logging when secure storage is unavailable and fallback mode activates
* **Enhanced Security**: Improved password-based key derivation (`deriveKey` method)
  * Increased default iterations from 10,000 to 100,000 for stronger key derivation
  * Added configurable iterations parameter for flexibility
  * Better documentation on security properties
* **Testing**: Added comprehensive test suite for encryption service
  * 26 new tests covering encryption, key generation, security properties, and edge cases
  * Regression tests to prevent future security vulnerabilities
* **No Breaking Changes**: Drop-in security improvement with full backward compatibility

## 1.0.5

* Dependency Updates: Updated to latest compatible versions for better pub.dev scoring
  * Updated `flutter_secure_storage` from ^9.0.0 to ^10.0.0
  * Updated `crypto` from ^3.0.3 to ^3.0.7
  * Updated `sqflite_common_ffi` from ^2.3.6 to ^2.4.0
  * Updated `flutter_lints` from ^3.0.0 to ^6.0.0
* Bug Fixes: Removed deprecated `encryptedSharedPreferences` parameter for Android (data automatically migrated)
* Compatibility: Improved compatibility with latest Flutter SDK and dependencies

## 1.0.4

* Improved API: Enhanced API consistency with new instance-based access patterns.
* Dual Access Support: Added better support for both factory methods (SecureDB.hive()) and direct instance access (SecureHive.instance).
* Performance & Stability: Enhanced singleton implementation for both Hive and SQLite and removed debug print statements.
* Documentation Update: Comprehensive documentation with updated usage examples and guides.