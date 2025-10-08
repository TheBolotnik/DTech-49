import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_chat_flutter/auth/auth_provider.dart';
import 'package:ai_chat_flutter/auth/auth_service.dart';
import 'package:ai_chat_flutter/auth/auth_state.dart';
import 'package:ai_chat_flutter/auth/credentials_repository.dart';
import 'package:ai_chat_flutter/auth/provider_detector.dart';
import 'package:ai_chat_flutter/services/database_service.dart';
import 'package:ai_chat_flutter/services/secure_keystore.dart';

/// Mock DatabaseService for testing
class MockDatabaseService implements DatabaseService {
  Map<String, dynamic>? _storedCredentials;

  @override
  Future<void> saveCredentials(Map<String, dynamic> json) async {
    _storedCredentials = json;
  }

  @override
  Future<Map<String, dynamic>?> readCredentials() async {
    return _storedCredentials;
  }

  @override
  Future<void> clearCredentials() async {
    _storedCredentials = null;
  }

  // Unused methods for this test
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock SecureKeyStore that tracks master key state
class MockSecureKeyStore implements SecureKeyStore {
  String? _masterKey;
  int _ensureCallCount = 0;

  @override
  Future<Uint8List> ensureMasterKey() async {
    _ensureCallCount++;
    _masterKey ??= List.generate(32, (i) => i).toString();
    return Uint8List.fromList(List.generate(32, (i) => i));
  }

  int get masterKeyAccessCount => _ensureCallCount;
  bool get hasMasterKey => _masterKey != null;

  // Unused methods for this test
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Integration test for complete reset flow
void main() {
  group('Reset Flow Integration Test', () {
    late AuthProvider authProvider;
    late AuthService authService;
    late CredentialsRepository repo;
    late MockDatabaseService mockDb;
    late MockSecureKeyStore mockKeyStore;

    setUp(() {
      mockDb = MockDatabaseService();
      mockKeyStore = MockSecureKeyStore();
      repo = CredentialsRepository(mockDb, mockKeyStore);
      authService = AuthService(repo);
      authProvider = AuthProvider(authService);
    });

    test('Complete reset flow: setup -> reset -> verify clean state', () async {
      // STEP 1: Initial state should be AuthNoKey
      expect(authProvider.state, isA<AuthNoKey>());

      // STEP 2: Submit API key and setup credentials
      await authProvider.submitApiKey('sk-or-v1-test-key-1234567890');

      // Should transition to PinSetup state
      expect(authProvider.state, isA<AuthPinSetup>());
      final pinState = authProvider.state as AuthPinSetup;
      final originalPin = pinState.pin;

      // STEP 3: Confirm PIN seen (simulates user acknowledging the PIN)
      await authProvider.confirmPinSeen();

      // Should transition to PinRequired state
      expect(authProvider.state, isA<AuthPinRequired>());

      // Verify credentials are stored
      final storedBeforeReset = await repo.read();
      expect(storedBeforeReset, isNotNull);
      expect(storedBeforeReset!.provider, ProviderType.openrouter);
      expect(storedBeforeReset.apiKeyData, isNotEmpty);
      expect(storedBeforeReset.pinHash, isNotEmpty);

      // Verify master key was created
      expect(mockKeyStore.hasMasterKey, true);
      final masterKeyAccessesBefore = mockKeyStore.masterKeyAccessCount;

      // STEP 4: Verify PIN works before reset
      await authProvider.enterPin(originalPin);
      expect(authProvider.state, isA<AuthAuthorized>());

      // Reset to PinRequired for reset test
      authProvider.state = AuthPinRequired();

      // STEP 5: EXECUTE RESET
      await authProvider.reset();

      // STEP 6: Verify state transitions to AuthNoKey
      expect(authProvider.state, isA<AuthNoKey>());

      // STEP 7: Verify credentials are wiped from database
      final storedAfterReset = await repo.read();
      expect(storedAfterReset, isNull);

      // STEP 8: Verify master key is PRESERVED (not deleted)
      expect(mockKeyStore.hasMasterKey, true);
      expect(
        mockKeyStore.masterKeyAccessCount,
        greaterThanOrEqualTo(masterKeyAccessesBefore),
        reason: 'Master key should still be accessible',
      );

      // STEP 9: Verify previous PIN no longer works
      await authProvider.enterPin(originalPin);
      expect(authProvider.state, isA<AuthError>());
      final errorState = authProvider.state as AuthError;
      expect(errorState.message, contains('Неверный PIN'));

      // STEP 10: Verify hasCredentials returns false
      final hasCredentials = await authService.hasCredentials();
      expect(hasCredentials, false);

      // STEP 11: Verify can setup new credentials after reset
      await authProvider.submitApiKey('sk-or-v1-new-key-0987654321');
      expect(authProvider.state, isA<AuthPinSetup>());

      final newPinState = authProvider.state as AuthPinSetup;
      expect(newPinState.pin, isNot(equals(originalPin)));

      // Verify new credentials are stored
      final newStored = await repo.read();
      expect(newStored, isNotNull);
      expect(newStored!.provider, ProviderType.openrouter);
    });

    test('Reset when no credentials exist should succeed', () async {
      // Initial state
      expect(authProvider.state, isA<AuthNoKey>());

      // Reset without any credentials
      await authProvider.reset();

      // Should remain in AuthNoKey state
      expect(authProvider.state, isA<AuthNoKey>());

      // Verify no credentials
      final stored = await repo.read();
      expect(stored, isNull);
    });

    test('Reset clears all credential fields from database', () async {
      // Setup credentials
      await authProvider.submitApiKey('sk-or-v1-test-key-1234567890');

      // Get stored credentials
      final beforeReset = await repo.read();
      expect(beforeReset, isNotNull);
      expect(beforeReset!.apiKeyData, isNotEmpty);
      expect(beforeReset.apiKeyMac, isNotEmpty);
      expect(beforeReset.apiKeyIv, isNotEmpty);
      expect(beforeReset.pinHash, isNotEmpty);
      expect(beforeReset.pinSalt, isNotEmpty);
      expect(beforeReset.currency, isNotEmpty);
      expect(beforeReset.balanceValue, greaterThan(0));

      // Reset
      await authProvider.reset();

      // Verify all data is gone
      final afterReset = await repo.read();
      expect(afterReset, isNull);
    });

    test('Multiple resets should not cause errors', () async {
      // Setup
      await authProvider.submitApiKey('sk-or-v1-test-key-1234567890');

      // First reset
      await authProvider.reset();
      expect(authProvider.state, isA<AuthNoKey>());

      // Second reset (redundant but should not error)
      await authProvider.reset();
      expect(authProvider.state, isA<AuthNoKey>());

      // Third reset
      await authProvider.reset();
      expect(authProvider.state, isA<AuthNoKey>());
    });

    test('Reset preserves master key for subsequent encryptions', () async {
      // Setup first credentials
      await authProvider.submitApiKey('sk-or-v1-test-key-1234567890');
      final accessesAfterFirst = mockKeyStore.masterKeyAccessCount;

      // Reset
      await authProvider.reset();

      // Setup new credentials (should reuse existing master key)
      await authProvider.submitApiKey('sk-or-v1-new-key-0987654321');
      final accessesAfterSecond = mockKeyStore.masterKeyAccessCount;

      // Master key should be reused (accessed but not recreated)
      expect(accessesAfterSecond, greaterThan(accessesAfterFirst));
      expect(mockKeyStore.hasMasterKey, true);
    });
  });
}
