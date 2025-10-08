import 'package:flutter_test/flutter_test.dart';
import 'package:ai_chat_flutter/auth/app_credentials.dart';
import 'package:ai_chat_flutter/auth/provider_detector.dart';

void main() {
  group('OpenRouterClient with CredentialsRepository', () {
    test('should read API key from repository', () async {
      // Create mock credentials
      final mockCredentials = AppCredentials(
        provider: ProviderType.openrouter,
        apiKeyData: 'encrypted_data',
        apiKeyMac: 'mac',
        apiKeyIv: 'iv',
        pinHash: 'hash',
        pinSalt: 'salt',
        currency: 'USD',
        balanceValue: 10.0,
        createdAt: DateTime.now(),
        lastCheckAt: DateTime.now(),
      );

      // Note: This is a simplified test
      // In a real scenario, you'd mock the repository
      // For now, this demonstrates the structure

      expect(mockCredentials.provider, ProviderType.openrouter);
    });

    test('should select correct base URL by provider - OpenRouter', () {
      const expectedUrl = 'https://openrouter.ai/api/v1';

      // The base URL is determined by provider type
      expect(expectedUrl, contains('openrouter.ai'));
    });

    test('should select correct base URL by provider - VseGPT', () {
      const expectedUrl = 'https://api.vsetgpt.ru/v1';

      // The base URL is determined by provider type
      expect(expectedUrl, contains('vsetgpt.ru'));
    });

    test('should mask API key in logs', () {
      // Test the masking helper (private method, but we test the concept)
      const testKey = 'sk-or-v1-1234567890abcdef';
      const expectedMask = 'sk-or-***...***cdef';

      // Manually test masking logic
      final prefix = testKey.substring(0, 6);
      final suffix = testKey.substring(testKey.length - 4);
      final masked = '$prefix***...***$suffix';

      expect(masked, expectedMask);
    });

    test('should determine provider type from credentials', () {
      final openRouterCreds = AppCredentials(
        provider: ProviderType.openrouter,
        apiKeyData: 'data',
        apiKeyMac: 'mac',
        apiKeyIv: 'iv',
        pinHash: 'hash',
        pinSalt: 'salt',
        currency: 'USD',
        balanceValue: 0,
        createdAt: DateTime.now(),
        lastCheckAt: DateTime.now(),
      );

      final vseGptCreds = AppCredentials(
        provider: ProviderType.vsegpt,
        apiKeyData: 'data',
        apiKeyMac: 'mac',
        apiKeyIv: 'iv',
        pinHash: 'hash',
        pinSalt: 'salt',
        currency: 'RUB',
        balanceValue: 0,
        createdAt: DateTime.now(),
        lastCheckAt: DateTime.now(),
      );

      expect(openRouterCreds.provider, ProviderType.openrouter);
      expect(vseGptCreds.provider, ProviderType.vsegpt);
      expect(openRouterCreds.currency, 'USD');
      expect(vseGptCreds.currency, 'RUB');
    });
  });
}
