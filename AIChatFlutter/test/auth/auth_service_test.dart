import 'package:flutter_test/flutter_test.dart';
import 'package:ai_chat_flutter/auth/auth_service.dart';
import 'package:ai_chat_flutter/auth/credentials_repository.dart';
import 'package:ai_chat_flutter/auth/app_credentials.dart';
import 'package:ai_chat_flutter/auth/provider_detector.dart';
import 'package:ai_chat_flutter/auth/balance_types.dart';
import 'package:ai_chat_flutter/auth/crypto_helper.dart';

/// Mock implementation of CredentialsRepository for testing
class MockCredentialsRepository implements CredentialsRepository {
  AppCredentials? _storedCredentials;
  Map<String, String>? _encryptionResult;

  @override
  Future<void> save(AppCredentials credentials) async {
    _storedCredentials = credentials;
  }

  @override
  Future<AppCredentials?> read() async {
    return _storedCredentials;
  }

  @override
  Future<void> clear() async {
    _storedCredentials = null;
  }

  @override
  Future<Map<String, String>> encryptApiKey(String apiKey) async {
    // Return mock encryption data
    _encryptionResult = {
      'data': 'encrypted_data_base64',
      'mac': 'mac_base64',
      'iv': 'iv_base64',
    };
    return _encryptionResult!;
  }

  @override
  Future<String> decryptApiKey(AppCredentials credentials) async {
    return 'decrypted_api_key';
  }
}

void main() {
  group('AuthService', () {
    late AuthService authService;
    late MockCredentialsRepository mockRepo;

    setUp(() {
      mockRepo = MockCredentialsRepository();
      authService = AuthService(mockRepo);
    });

    group('checkAndStoreKey', () {
      test('throws BadResponseError for empty API key', () async {
        expect(
          () => authService.checkAndStoreKey(''),
          throwsA(isA<BadResponseError>()),
        );
      });

      test('throws BadResponseError for whitespace-only API key', () async {
        expect(
          () => authService.checkAndStoreKey('   '),
          throwsA(isA<BadResponseError>()),
        );
      });

      test('throws BadResponseError for invalid format API key', () async {
        expect(
          () => authService.checkAndStoreKey('invalid-key'),
          throwsA(isA<BadResponseError>()),
        );
      });

      test('throws BadResponseError for unknown provider', () async {
        expect(
          () => authService.checkAndStoreKey('sk-unknown-1234567890abcdef'),
          throwsA(isA<BadResponseError>()),
        );
      });

      test('returns PIN and saves credentials for valid OpenRouter key',
          () async {
        // Note: This test requires kUseMockBalance=true in balance_client_mock.dart
        final result =
            await authService.checkAndStoreKey('sk-or-v1-test-key-1234567890');

        // Verify result
        expect(result, isA<AuthResultPinSetup>());
        expect(result.pin, hasLength(4));
        expect(result.pin, matches(RegExp(r'^\d{4}$')));
        expect(result.provider, ProviderType.openrouter);

        // Verify credentials were saved
        final stored = await mockRepo.read();
        expect(stored, isNotNull);
        expect(stored!.provider, ProviderType.openrouter);
        expect(stored.apiKeyData, 'encrypted_data_base64');
        expect(stored.apiKeyMac, 'mac_base64');
        expect(stored.apiKeyIv, 'iv_base64');
        expect(stored.pinHash, isNotEmpty);
        expect(stored.pinSalt, isNotEmpty);
        expect(stored.currency, 'USD');
        expect(stored.balanceValue, 5.5);
        expect(stored.createdAt, isNotNull);
        expect(stored.lastCheckAt, isNotNull);

        // Verify PIN can be validated
        final isValid = await CryptoHelper.verifyPin(
          result.pin,
          stored.pinHash,
          stored.pinSalt,
        );
        expect(isValid, true);
      });

      test('returns PIN and saves credentials for valid VseGPT key', () async {
        final result =
            await authService.checkAndStoreKey('sk-or-vv-test-key-1234567890');

        // Verify result
        expect(result, isA<AuthResultPinSetup>());
        expect(result.pin, hasLength(4));
        expect(result.provider, ProviderType.vsegpt);

        // Verify credentials were saved
        final stored = await mockRepo.read();
        expect(stored, isNotNull);
        expect(stored!.provider, ProviderType.vsegpt);
        expect(stored.currency, 'RUB');
        expect(stored.balanceValue, 250.0);
      });

      test('generates 4-digit PIN with leading zeros support', () async {
        // Run multiple times to check PIN format consistency
        for (var i = 0; i < 5; i++) {
          final result = await authService
              .checkAndStoreKey('sk-or-v1-test-key-1234567890$i');

          expect(result.pin, hasLength(4));
          expect(result.pin, matches(RegExp(r'^\d{4}$')));

          // PIN should be valid number 0-9999
          final pinValue = int.parse(result.pin);
          expect(pinValue, greaterThanOrEqualTo(0));
          expect(pinValue, lessThan(10000));
        }
      });

      test('trims whitespace from API key', () async {
        final result = await authService
            .checkAndStoreKey('  sk-or-v1-test-key-1234567890  ');

        expect(result.provider, ProviderType.openrouter);
        final stored = await mockRepo.read();
        expect(stored, isNotNull);
      });
    });

    group('verifyPin', () {
      test('returns false when no credentials exist', () async {
        final result = await authService.verifyPin('1234');
        expect(result, false);
      });

      test('returns true for correct PIN', () async {
        // First store credentials
        final setup =
            await authService.checkAndStoreKey('sk-or-v1-test-key-1234567890');

        // Verify correct PIN
        final result = await authService.verifyPin(setup.pin);
        expect(result, true);
      });

      test('returns false for incorrect PIN', () async {
        // First store credentials
        final setup =
            await authService.checkAndStoreKey('sk-or-v1-test-key-1234567890');

        // Verify incorrect PIN
        final wrongPin = setup.pin == '0000' ? '9999' : '0000';
        final result = await authService.verifyPin(wrongPin);
        expect(result, false);
      });

      test('returns false for PIN with different length', () async {
        // First store credentials
        await authService.checkAndStoreKey('sk-or-v1-test-key-1234567890');

        // Verify with wrong length
        expect(await authService.verifyPin('123'), false);
        expect(await authService.verifyPin('12345'), false);
      });
    });

    group('reset', () {
      test('clears stored credentials', () async {
        // First store credentials
        await authService.checkAndStoreKey('sk-or-v1-test-key-1234567890');

        // Verify credentials exist
        expect(await mockRepo.read(), isNotNull);

        // Reset
        await authService.reset();

        // Verify credentials cleared
        expect(await mockRepo.read(), isNull);
      });

      test('can be called when no credentials exist', () async {
        // Should not throw
        await authService.reset();
        expect(await mockRepo.read(), isNull);
      });
    });

    group('hasCredentials', () {
      test('returns false when no credentials exist', () async {
        final result = await authService.hasCredentials();
        expect(result, false);
      });

      test('returns true when credentials exist', () async {
        // Store credentials
        await authService.checkAndStoreKey('sk-or-v1-test-key-1234567890');

        // Check credentials exist
        final result = await authService.hasCredentials();
        expect(result, true);
      });

      test('returns false after reset', () async {
        // Store and reset
        await authService.checkAndStoreKey('sk-or-v1-test-key-1234567890');
        await authService.reset();

        // Check credentials do not exist
        final result = await authService.hasCredentials();
        expect(result, false);
      });
    });
  });
}
