import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_chat_flutter/auth/auth_service.dart';
import 'package:ai_chat_flutter/auth/credentials_repository.dart';
import 'package:ai_chat_flutter/auth/provider_detector.dart';
import 'package:ai_chat_flutter/services/database_service.dart';
import 'package:ai_chat_flutter/services/secure_keystore.dart';

/// Fake DatabaseService for testing - implements credential methods only
class FakeDatabaseService implements DatabaseService {
  Map<String, dynamic>? _storedCredentials;

  @override
  Future<void> saveCredentials(Map<String, dynamic> json) async {
    _storedCredentials = Map<String, dynamic>.from(json);
  }

  @override
  Future<Map<String, dynamic>?> readCredentials() async {
    if (_storedCredentials == null) return null;
    return Map<String, dynamic>.from(_storedCredentials!);
  }

  @override
  Future<void> clearCredentials() async {
    _storedCredentials = null;
  }

  // Unimplemented methods (not needed for these tests)
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake SecureKeyStore for testing
class FakeSecureKeyStore implements SecureKeyStore {
  Uint8List? _masterKey;

  @override
  Future<Uint8List> ensureMasterKey() async {
    // Generate a consistent key for testing
    _masterKey ??= Uint8List.fromList(List.generate(32, (i) => i));
    return _masterKey!;
  }

  @override
  Future<void> saveKey(String keyId, String value) async {
    // No-op for testing
  }

  @override
  Future<String?> readKey(String keyId) async {
    // No-op for testing
    return null;
  }

  @override
  Future<void> deleteKey(String keyId) async {
    // No-op for testing
  }
}

void main() {
  group('Auth Flow Integration Tests', () {
    late AuthService authService;
    late FakeDatabaseService fakeDb;
    late FakeSecureKeyStore fakeKs;
    late CredentialsRepository repo;

    setUp(() {
      fakeDb = FakeDatabaseService();
      fakeKs = FakeSecureKeyStore();
      repo = CredentialsRepository(fakeDb, fakeKs);
      authService = AuthService(repo);
    });

    group('Happy Path', () {
      test('checkAndStoreKey returns PIN and saves credentials for OpenRouter',
          () async {
        // Arrange
        const apiKey = 'sk-or-v1-test123456789abcdef';

        // Act - Check and store the key (uses mock balance client)
        final result = await authService.checkAndStoreKey(apiKey);

        // Assert - Should return a PIN and provider
        expect(result.pin, isNotEmpty);
        expect(result.pin.length, 4);
        expect(result.pin, matches(RegExp(r'^\d{4}$'))); // 4 digits
        expect(result.provider, ProviderType.openrouter);

        // Verify credentials were saved
        final hasCredentials = await authService.hasCredentials();
        expect(hasCredentials, isTrue);

        // Verify the returned PIN can be verified
        final pinValid = await authService.verifyPin(result.pin);
        expect(pinValid, isTrue);
      });

      test('checkAndStoreKey returns PIN and saves credentials for VseGPT',
          () async {
        // Arrange
        const apiKey = 'sk-or-vv-test123456789abcdef';

        // Act - Check and store the key (uses mock balance client)
        final result = await authService.checkAndStoreKey(apiKey);

        // Assert - Should return a PIN and provider
        expect(result.pin, isNotEmpty);
        expect(result.pin.length, 4);
        expect(result.pin, matches(RegExp(r'^\d{4}$'))); // 4 digits
        expect(result.provider, ProviderType.vsegpt);

        // Verify credentials were saved
        final hasCredentials = await authService.hasCredentials();
        expect(hasCredentials, isTrue);

        // Verify the returned PIN can be verified
        final pinValid = await authService.verifyPin(result.pin);
        expect(pinValid, isTrue);
      });

      test('verifyPin returns true for correct PIN and false for wrong PIN',
          () async {
        // Arrange - Set up credentials first
        const apiKey = 'sk-or-v1-test123456789abcdef';
        final result = await authService.checkAndStoreKey(apiKey);
        final correctPin = result.pin;

        // Act & Assert - Verify correct PIN
        final correctPinValid = await authService.verifyPin(correctPin);
        expect(correctPinValid, isTrue);

        // Act & Assert - Verify wrong PIN
        final wrongPinValid = await authService.verifyPin('0000');
        expect(wrongPinValid, isFalse);

        // Act & Assert - Verify another wrong PIN
        final anotherWrongPin = await authService.verifyPin('9999');
        expect(anotherWrongPin, isFalse);
      });

      test('verifyPin returns false when no credentials exist', () async {
        // Act - Try to verify a PIN with no stored credentials
        final result = await authService.verifyPin('1234');

        // Assert
        expect(result, isFalse);
      });

      test('PIN has leading zeros preserved', () async {
        // This test verifies that PINs with leading zeros are properly handled
        // We can't control the random PIN generation, but we can verify
        // that the system properly handles 4-digit PINs including those with leading zeros

        // Arrange
        const apiKey = 'sk-or-v1-test123456789abcdef';

        // Act - Generate multiple PINs to increase chance of getting one with leading zero
        final pins = <String>[];
        for (var i = 0; i < 20; i++) {
          await authService.reset();
          final result = await authService.checkAndStoreKey(apiKey);
          pins.add(result.pin);

          // Verify each PIN is exactly 4 digits
          expect(result.pin.length, 4);
          expect(result.pin, matches(RegExp(r'^\d{4}$')));
        }

        // Assert - At least verify all PINs are properly formatted
        expect(pins.every((pin) => pin.length == 4), isTrue);
      });
    });

    group('Reset Flow', () {
      test('reset clears credentials and hasCredentials returns false',
          () async {
        // Arrange - Set up credentials first
        const apiKey = 'sk-or-v1-test123456789abcdef';
        await authService.checkAndStoreKey(apiKey);

        // Verify credentials exist
        var hasCredentials = await authService.hasCredentials();
        expect(hasCredentials, isTrue);

        // Act - Reset
        await authService.reset();

        // Assert - Credentials should be cleared
        hasCredentials = await authService.hasCredentials();
        expect(hasCredentials, isFalse);
      });

      test('reset allows new credentials to be stored', () async {
        // Arrange - Set up initial credentials
        const apiKey1 = 'sk-or-v1-firstkey123456789';
        final result1 = await authService.checkAndStoreKey(apiKey1);
        final pin1 = result1.pin;

        // Act - Reset and store new credentials
        await authService.reset();
        const apiKey2 = 'sk-or-v1-secondkey987654321';
        final result2 = await authService.checkAndStoreKey(apiKey2);
        final pin2 = result2.pin;

        // Assert - Old PIN should not work
        final oldPinValid = await authService.verifyPin(pin1);
        expect(oldPinValid, isFalse);

        // Assert - New PIN should work
        final newPinValid = await authService.verifyPin(pin2);
        expect(newPinValid, isTrue);

        // Assert - PINs should likely be different (not guaranteed but highly probable)
        // We don't assert this because there's a 1/10000 chance they could be the same
      });

      test('verifyPin returns false after reset', () async {
        // Arrange - Set up credentials
        const apiKey = 'sk-or-v1-test123456789abcdef';
        final result = await authService.checkAndStoreKey(apiKey);
        final pin = result.pin;

        // Verify PIN works before reset
        var pinValid = await authService.verifyPin(pin);
        expect(pinValid, isTrue);

        // Act - Reset
        await authService.reset();

        // Assert - PIN should no longer work
        pinValid = await authService.verifyPin(pin);
        expect(pinValid, isFalse);
      });
    });

    group('Edge Cases', () {
      test('hasCredentials returns false initially', () async {
        // Act
        final hasCredentials = await authService.hasCredentials();

        // Assert
        expect(hasCredentials, isFalse);
      });

      test('multiple checkAndStoreKey calls overwrite credentials', () async {
        // Arrange
        const apiKey1 = 'sk-or-v1-firstkey123456789';
        const apiKey2 = 'sk-or-v1-secondkey987654321';

        // Act - Store first key
        final result1 = await authService.checkAndStoreKey(apiKey1);
        final pin1 = result1.pin;

        // Act - Store second key (should overwrite)
        final result2 = await authService.checkAndStoreKey(apiKey2);
        final pin2 = result2.pin;

        // Assert - First PIN should no longer work
        final pin1Valid = await authService.verifyPin(pin1);
        expect(pin1Valid, isFalse);

        // Assert - Second PIN should work
        final pin2Valid = await authService.verifyPin(pin2);
        expect(pin2Valid, isTrue);
      });

      test('verifyPin handles empty string', () async {
        // Arrange - Set up credentials
        const apiKey = 'sk-or-v1-test123456789abcdef';
        await authService.checkAndStoreKey(apiKey);

        // Act
        final result = await authService.verifyPin('');

        // Assert
        expect(result, isFalse);
      });

      test('verifyPin handles non-numeric input', () async {
        // Arrange - Set up credentials
        const apiKey = 'sk-or-v1-test123456789abcdef';
        await authService.checkAndStoreKey(apiKey);

        // Act
        final result = await authService.verifyPin('abcd');

        // Assert
        expect(result, isFalse);
      });

      test('verifyPin handles wrong length PINs', () async {
        // Arrange - Set up credentials
        const apiKey = 'sk-or-v1-test123456789abcdef';
        await authService.checkAndStoreKey(apiKey);

        // Act & Assert - Too short
        var result = await authService.verifyPin('123');
        expect(result, isFalse);

        // Act & Assert - Too long
        result = await authService.verifyPin('12345');
        expect(result, isFalse);
      });
    });
  });
}
