import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_chat_flutter/auth/credentials_repository.dart';
import 'package:ai_chat_flutter/auth/app_credentials.dart';
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
  late CredentialsRepository repository;
  late FakeDatabaseService fakeDb;
  late FakeSecureKeyStore fakeKs;

  setUp(() {
    fakeDb = FakeDatabaseService();
    fakeKs = FakeSecureKeyStore();
    repository = CredentialsRepository(fakeDb, fakeKs);
  });

  group('CredentialsRepository', () {
    test('save → read → decrypt roundtrip returns original API key', () async {
      // Arrange
      const originalApiKey = 'sk-or-v1-test123456789abcdef';
      final encrypted = await repository.encryptApiKey(originalApiKey);

      final credentials = AppCredentials(
        provider: ProviderType.openrouter,
        apiKeyData: encrypted['data']!,
        apiKeyMac: encrypted['mac']!,
        apiKeyIv: encrypted['iv']!,
        pinHash: 'test_pin_hash',
        pinSalt: 'test_pin_salt',
        currency: 'USD',
        balanceValue: 10.0,
        createdAt: DateTime.now(),
        lastCheckAt: DateTime.now(),
      );

      // Act - Save credentials
      await repository.save(credentials);

      // Read back
      final readCredentials = await repository.read();

      // Verify credentials were saved and read correctly
      expect(readCredentials, isNotNull);
      expect(readCredentials!.provider, ProviderType.openrouter);
      expect(readCredentials.apiKeyData, encrypted['data']);
      expect(readCredentials.apiKeyMac, encrypted['mac']);
      expect(readCredentials.apiKeyIv, encrypted['iv']);
      expect(readCredentials.currency, 'USD');
      expect(readCredentials.balanceValue, 10.0);

      // Decrypt the API key
      final decryptedApiKey = await repository.decryptApiKey(readCredentials);

      // Assert - Original API key should match decrypted key
      expect(decryptedApiKey, originalApiKey);
    });

    test('clear removes entry', () async {
      // Arrange
      const originalApiKey = 'sk-or-vv-test123456789abcdef';
      final encrypted = await repository.encryptApiKey(originalApiKey);

      final credentials = AppCredentials(
        provider: ProviderType.vsegpt,
        apiKeyData: encrypted['data']!,
        apiKeyMac: encrypted['mac']!,
        apiKeyIv: encrypted['iv']!,
        pinHash: 'test_pin_hash',
        pinSalt: 'test_pin_salt',
        currency: 'RUB',
        balanceValue: 100.0,
        createdAt: DateTime.now(),
        lastCheckAt: DateTime.now(),
      );

      // Act - Save then clear
      await repository.save(credentials);
      await repository.clear();

      // Assert - Reading should return null
      final readCredentials = await repository.read();
      expect(readCredentials, isNull);
    });

    test('read returns null when no credentials stored', () async {
      // Act
      final result = await repository.read();

      // Assert
      expect(result, isNull);
    });

    test('encryptApiKey produces valid encryption data', () async {
      // Arrange
      const apiKey = 'sk-or-v1-testkeyvalue123456789';

      // Act
      final encrypted = await repository.encryptApiKey(apiKey);

      // Assert
      expect(encrypted, containsPair('data', isNotEmpty));
      expect(encrypted, containsPair('mac', isNotEmpty));
      expect(encrypted, containsPair('iv', isNotEmpty));
    });

    test('encrypted data is different for same API key on different calls',
        () async {
      // Arrange
      const apiKey = 'sk-or-v1-samekey12345678';

      // Act
      final encrypted1 = await repository.encryptApiKey(apiKey);
      final encrypted2 = await repository.encryptApiKey(apiKey);

      // Assert - Encrypted data should be different due to random IV
      expect(encrypted1['data'], isNot(equals(encrypted2['data'])));
      expect(encrypted1['iv'], isNot(equals(encrypted2['iv'])));
    });

    test('toJson and fromJson preserve all credential fields', () async {
      // Arrange
      final now = DateTime.now();
      final credentials = AppCredentials(
        provider: ProviderType.openrouter,
        apiKeyData: 'test_data',
        apiKeyMac: 'test_mac',
        apiKeyIv: 'test_iv',
        pinHash: 'test_hash',
        pinSalt: 'test_salt',
        currency: 'USD',
        balanceValue: 25.50,
        createdAt: now,
        lastCheckAt: now,
      );

      // Act
      final json = credentials.toJson();
      final restored = AppCredentials.fromJson(json);

      // Assert
      expect(restored.provider, credentials.provider);
      expect(restored.apiKeyData, credentials.apiKeyData);
      expect(restored.apiKeyMac, credentials.apiKeyMac);
      expect(restored.apiKeyIv, credentials.apiKeyIv);
      expect(restored.pinHash, credentials.pinHash);
      expect(restored.pinSalt, credentials.pinSalt);
      expect(restored.currency, credentials.currency);
      expect(restored.balanceValue, credentials.balanceValue);
      expect(restored.createdAt.toIso8601String(),
          credentials.createdAt.toIso8601String());
      expect(restored.lastCheckAt.toIso8601String(),
          credentials.lastCheckAt.toIso8601String());
    });

    test('copyWith creates modified copy', () async {
      // Arrange
      final original = AppCredentials(
        provider: ProviderType.openrouter,
        apiKeyData: 'data1',
        apiKeyMac: 'mac1',
        apiKeyIv: 'iv1',
        pinHash: 'hash1',
        pinSalt: 'salt1',
        currency: 'USD',
        balanceValue: 10.0,
        createdAt: DateTime.now(),
        lastCheckAt: DateTime.now(),
      );

      // Act
      final modified = original.copyWith(
        currency: 'RUB',
        balanceValue: 20.0,
      );

      // Assert
      expect(modified.currency, 'RUB');
      expect(modified.balanceValue, 20.0);
      expect(modified.provider, original.provider);
      expect(modified.apiKeyData, original.apiKeyData);
    });
  });
}
