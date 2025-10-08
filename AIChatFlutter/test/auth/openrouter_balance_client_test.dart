import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:ai_chat_flutter/auth/balance_client.dart';
import 'package:ai_chat_flutter/auth/balance_types.dart';
import 'package:ai_chat_flutter/auth/provider_detector.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('OpenRouter BalanceClient', () {
    late MockHttpClient mockClient;
    late BalanceClient balanceClient;

    setUp(() {
      mockClient = MockHttpClient();
      balanceClient = HttpBalanceClient(mockClient);
    });

    test('returns valid status with limit_remaining as 6.75', () async {
      final responseBody = jsonEncode({
        'data': {
          'limit_remaining': 6.75,
        },
      });

      when(() => mockClient.get(
            Uri.parse('https://openrouter.ai/api/v1/key'),
            headers: {'Authorization': 'Bearer sk-or-v1-test-key-1234567890'},
          )).thenAnswer((_) async => http.Response(
            responseBody,
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await balanceClient.check(
        'sk-or-v1-test-key-1234567890',
        ProviderType.openrouter,
      );

      expect(result.isValidKey, true);
      expect(result.hasPositiveBalance, true);
      expect(result.currency, 'USD');
      expect(result.value, 6.75);
      expect(result.raw['data']['limit_remaining'], 6.75);
    });

    test('returns valid status with limit_remaining as null', () async {
      final responseBody = jsonEncode({
        'data': {
          'limit_remaining': null,
        },
      });

      when(() => mockClient.get(
            Uri.parse('https://openrouter.ai/api/v1/key'),
            headers: {'Authorization': 'Bearer sk-or-v1-test-key-1234567890'},
          )).thenAnswer((_) async => http.Response(
            responseBody,
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await balanceClient.check(
        'sk-or-v1-test-key-1234567890',
        ProviderType.openrouter,
      );

      expect(result.isValidKey, true);
      expect(result.hasPositiveBalance, true);
      expect(result.currency, 'USD');
      expect(result.value, null);
    });

    test('returns valid status with limit_remaining as 0', () async {
      final responseBody = jsonEncode({
        'data': {
          'limit_remaining': 0.0,
        },
      });

      when(() => mockClient.get(
            Uri.parse('https://openrouter.ai/api/v1/key'),
            headers: {'Authorization': 'Bearer sk-or-v1-test-key-1234567890'},
          )).thenAnswer((_) async => http.Response(
            responseBody,
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await balanceClient.check(
        'sk-or-v1-test-key-1234567890',
        ProviderType.openrouter,
      );

      expect(result.isValidKey, true);
      expect(result.hasPositiveBalance, false);
      expect(result.value, 0.0);
    });

    test('throws InvalidKeyError on 401 status code', () async {
      when(() => mockClient.get(
            Uri.parse('https://openrouter.ai/api/v1/key'),
            headers: {'Authorization': 'Bearer invalid-key'},
          )).thenAnswer((_) async => http.Response('Unauthorized', 401));

      expect(
        () => balanceClient.check('invalid-key', ProviderType.openrouter),
        throwsA(isA<InvalidKeyError>()),
      );
    });

    test('throws InvalidKeyError on 403 status code', () async {
      when(() => mockClient.get(
            Uri.parse('https://openrouter.ai/api/v1/key'),
            headers: {'Authorization': 'Bearer forbidden-key'},
          )).thenAnswer((_) async => http.Response('Forbidden', 403));

      expect(
        () => balanceClient.check('forbidden-key', ProviderType.openrouter),
        throwsA(isA<InvalidKeyError>()),
      );
    });

    test('throws InsufficientFundsError on 402 status code', () async {
      when(() => mockClient.get(
            Uri.parse('https://openrouter.ai/api/v1/key'),
            headers: {'Authorization': 'Bearer sk-or-v1-no-funds-key'},
          )).thenAnswer((_) async => http.Response('Payment Required', 402));

      expect(
        () => balanceClient.check(
            'sk-or-v1-no-funds-key', ProviderType.openrouter),
        throwsA(isA<InsufficientFundsError>()),
      );
    });

    test('throws NetworkError on 429 status code', () async {
      when(() => mockClient.get(
            Uri.parse('https://openrouter.ai/api/v1/key'),
            headers: {'Authorization': 'Bearer sk-or-v1-test-key'},
          )).thenAnswer((_) async => http.Response('Too Many Requests', 429));

      expect(
        () => balanceClient.check('sk-or-v1-test-key', ProviderType.openrouter),
        throwsA(isA<NetworkError>()),
      );
    });

    test('throws NetworkError on 500 status code', () async {
      when(() => mockClient.get(
            Uri.parse('https://openrouter.ai/api/v1/key'),
            headers: {'Authorization': 'Bearer sk-or-v1-test-key'},
          )).thenAnswer((_) async => http.Response('Server Error', 500));

      expect(
        () => balanceClient.check('sk-or-v1-test-key', ProviderType.openrouter),
        throwsA(isA<NetworkError>()),
      );
    });

    test('throws BadResponseError on invalid JSON', () async {
      when(() => mockClient.get(
            Uri.parse('https://openrouter.ai/api/v1/key'),
            headers: {'Authorization': 'Bearer sk-or-v1-test-key'},
          )).thenAnswer((_) async => http.Response(
            'Not JSON',
            200,
            headers: {'content-type': 'application/json'},
          ));

      expect(
        () => balanceClient.check('sk-or-v1-test-key', ProviderType.openrouter),
        throwsA(isA<BadResponseError>()),
      );
    });

    test('throws BadResponseError on HTML response', () async {
      when(() => mockClient.get(
            Uri.parse('https://openrouter.ai/api/v1/key'),
            headers: {'Authorization': 'Bearer sk-or-v1-test-key'},
          )).thenAnswer((_) async => http.Response(
            '<html><body>Error page</body></html>',
            200,
            headers: {'content-type': 'text/html'},
          ));

      expect(
        () => balanceClient.check('sk-or-v1-test-key', ProviderType.openrouter),
        throwsA(isA<BadResponseError>()),
      );
    });
  });
}
