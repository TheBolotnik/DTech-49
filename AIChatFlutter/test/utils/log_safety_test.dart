import 'package:flutter_test/flutter_test.dart';
import 'package:ai_chat_flutter/utils/log_safety.dart';

void main() {
  group('maskApiKey', () {
    test('masks OpenRouter API key correctly', () {
      const key = 'sk-or-v1-1234567890abcdef1234567890abcdef12345678';
      final masked = maskApiKey(key);

      expect(masked, contains('sk-or-v1-'));
      expect(masked, contains('***'));
      expect(masked, isNot(contains('1234567890abcdef')));
      expect(masked.length, lessThan(key.length));
    });

    test('masks VseGPT API key correctly', () {
      const key = 'sk-or-vv-1234567890abcdef1234567890abcdef12345678';
      final masked = maskApiKey(key);

      expect(masked, contains('sk-or-vv'));
      expect(masked, contains('***'));
      expect(masked.length, lessThan(key.length));
    });

    test('handles short keys', () {
      const key = 'short';
      final masked = maskApiKey(key);

      expect(masked, contains('***'));
      expect(masked, isNot(equals(key)));
    });

    test('handles empty string', () {
      const key = '';
      final masked = maskApiKey(key);

      expect(masked, equals('(empty)'));
    });

    test('shows prefix and suffix for normal keys', () {
      const key = 'sk-or-v1-1234567890abcdef1234567890abcdef12345678';
      final masked = maskApiKey(key);

      // Should show prefix
      expect(masked, startsWith('sk-or-v1-'));
      // Should show suffix (last few chars)
      expect(masked, endsWith('5678'));
      // Should contain masking
      expect(masked, contains('***...***'));
    });

    test('does not leak sensitive middle section', () {
      const key = 'sk-or-v1-SENSITIVE_MIDDLE_PART_HERE_1234567890';
      final masked = maskApiKey(key);

      expect(masked, isNot(contains('SENSITIVE_MIDDLE_PART_HERE')));
    });
  });

  group('maskCredentialInfo', () {
    test('removes PIN hash and salt', () {
      final info = {
        'pinHash': 'secret_hash',
        'pinSalt': 'secret_salt',
        'provider': 'openrouter',
      };

      final masked = maskCredentialInfo(info);

      expect(masked, isNot(contains('secret_hash')));
      expect(masked, isNot(contains('secret_salt')));
      expect(masked, contains('openrouter'));
    });

    test('removes decrypted API key', () {
      final info = {
        'apiKey': 'sk-or-v1-secret',
        'decryptedApiKey': 'sk-or-v1-secret',
        'provider': 'openrouter',
      };

      final masked = maskCredentialInfo(info);

      expect(masked, isNot(contains('sk-or-v1-secret')));
      expect(masked, contains('openrouter'));
    });

    test('masks encrypted data fields', () {
      final info = {
        'apiKeyData': 'base64_encrypted_data',
        'apiKeyMac': 'base64_mac',
        'apiKeyIv': 'base64_iv',
        'provider': 'openrouter',
      };

      final masked = maskCredentialInfo(info);

      expect(masked, isNot(contains('base64_encrypted_data')));
      expect(masked, isNot(contains('base64_mac')));
      expect(masked, isNot(contains('base64_iv')));
      expect(masked, contains('<encrypted>'));
      expect(masked, contains('<mac>'));
      expect(masked, contains('<iv>'));
    });

    test('preserves safe fields', () {
      final info = {
        'provider': 'openrouter',
        'currency': 'USD',
        'balanceValue': 10.5,
        'pinHash': 'should_be_removed',
      };

      final masked = maskCredentialInfo(info);

      expect(masked, contains('openrouter'));
      expect(masked, contains('USD'));
      expect(masked, contains('10.5'));
      expect(masked, isNot(contains('should_be_removed')));
    });
  });
}
