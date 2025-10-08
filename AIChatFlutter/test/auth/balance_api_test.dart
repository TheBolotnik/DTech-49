import 'package:flutter_test/flutter_test.dart';
import 'package:ai_chat_flutter/auth/balance_api.dart';
import 'package:ai_chat_flutter/auth/balance_types.dart';
import 'package:ai_chat_flutter/auth/balance_client_mock.dart';

void main() {
  group('Balance API', () {
    // Note: These tests work with kUseMockBalance=true in balance_client_mock.dart

    test('throws BadResponseError for empty API key', () async {
      expect(
        () => checkBalanceForApiKey(''),
        throwsA(isA<BadResponseError>()),
      );
    });

    test('throws BadResponseError for whitespace-only API key', () async {
      expect(
        () => checkBalanceForApiKey('   '),
        throwsA(isA<BadResponseError>()),
      );
    });

    test('throws BadResponseError for invalid format API key', () async {
      expect(
        () => checkBalanceForApiKey('invalid-key'),
        throwsA(isA<BadResponseError>()),
      );
    });

    test('throws BadResponseError for short API key', () async {
      expect(
        () => checkBalanceForApiKey('sk-or-v1-abc'),
        throwsA(isA<BadResponseError>()),
      );
    });

    test('checks balance for valid OpenRouter key when mock enabled', () async {
      // This test requires kUseMockBalance=true to pass
      if (kUseMockBalance) {
        final result =
            await checkBalanceForApiKey('sk-or-v1-test-key-1234567890');

        expect(result.isValidKey, true);
        expect(result.hasPositiveBalance, true);
        expect(result.currency, 'USD');
        expect(result.value, 5.5);
        expect(result.raw['mock'], true);
        expect(result.raw['provider'], 'openrouter');
      }
    });

    test('checks balance for valid VseGPT key when mock enabled', () async {
      // This test requires kUseMockBalance=true to pass
      if (kUseMockBalance) {
        final result =
            await checkBalanceForApiKey('sk-or-vv-test-key-1234567890');

        expect(result.isValidKey, true);
        expect(result.hasPositiveBalance, true);
        expect(result.currency, 'RUB');
        expect(result.value, 250.0);
        expect(result.raw['mock'], true);
        expect(result.raw['provider'], 'vsegpt');
      }
    });

    test('trims whitespace from API key before processing', () async {
      if (kUseMockBalance) {
        final result =
            await checkBalanceForApiKey('  sk-or-v1-test-key-1234567890  ');

        expect(result.isValidKey, true);
        expect(result.currency, 'USD');
      }
    });
  });
}
