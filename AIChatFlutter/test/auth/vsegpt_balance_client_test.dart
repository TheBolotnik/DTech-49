import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:ai_chat_flutter/auth/balance_client.dart';
import 'package:ai_chat_flutter/auth/balance_types.dart';
import 'package:ai_chat_flutter/auth/provider_detector.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('VseGPT BalanceClient', () {
    late MockHttpClient mockClient;
    late BalanceClient balanceClient;

    setUp(() {
      mockClient = MockHttpClient();
      balanceClient = HttpBalanceClient(mockClient);
    });

    test('returns valid status with balance as 123.45', () async {
      final responseBody = jsonEncode({
        'balance': 123.45,
        'currency': 'RUB',
      });

      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer sk-or-vv-test-key-1234567890'},
          )).thenAnswer((_) async => http.Response(
            responseBody,
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await balanceClient.check(
        'sk-or-vv-test-key-1234567890',
        ProviderType.vsegpt,
      );

      expect(result.isValidKey, true);
      expect(result.hasPositiveBalance, true);
      expect(result.currency, 'RUB');
      expect(result.value, 123.45);
      expect(result.raw['balance'], 123.45);
    });

    test('returns valid status with balance as 0', () async {
      final responseBody = jsonEncode({
        'balance': 0,
      });

      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer sk-or-vv-test-key-1234567890'},
          )).thenAnswer((_) async => http.Response(
            responseBody,
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await balanceClient.check(
        'sk-or-vv-test-key-1234567890',
        ProviderType.vsegpt,
      );

      expect(result.isValidKey, true);
      expect(result.hasPositiveBalance, false);
      expect(result.currency, 'RUB');
      expect(result.value, 0.0);
    });

    test('extracts balance from "amount" field if "balance" not present',
        () async {
      final responseBody = jsonEncode({
        'amount': 50.25,
        'currency': 'RUB',
      });

      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer sk-or-vv-test-key-1234567890'},
          )).thenAnswer((_) async => http.Response(
            responseBody,
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await balanceClient.check(
        'sk-or-vv-test-key-1234567890',
        ProviderType.vsegpt,
      );

      expect(result.value, 50.25);
      expect(result.hasPositiveBalance, true);
    });

    test('extracts balance from "credits" field if others not present',
        () async {
      final responseBody = jsonEncode({
        'credits': 75.5,
      });

      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer sk-or-vv-test-key-1234567890'},
          )).thenAnswer((_) async => http.Response(
            responseBody,
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await balanceClient.check(
        'sk-or-vv-test-key-1234567890',
        ProviderType.vsegpt,
      );

      expect(result.value, 75.5);
      expect(result.hasPositiveBalance, true);
    });

    test('defaults to RUB currency if not specified', () async {
      final responseBody = jsonEncode({
        'balance': 100.0,
      });

      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer sk-or-vv-test-key-1234567890'},
          )).thenAnswer((_) async => http.Response(
            responseBody,
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await balanceClient.check(
        'sk-or-vv-test-key-1234567890',
        ProviderType.vsegpt,
      );

      expect(result.currency, 'RUB');
    });

    test('uses custom currency if provided', () async {
      final responseBody = jsonEncode({
        'balance': 100.0,
        'currency': 'USD',
      });

      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer sk-or-vv-test-key-1234567890'},
          )).thenAnswer((_) async => http.Response(
            responseBody,
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await balanceClient.check(
        'sk-or-vv-test-key-1234567890',
        ProviderType.vsegpt,
      );

      expect(result.currency, 'USD');
    });

    test('throws InsufficientFundsError on 402 status code', () async {
      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer sk-or-vv-no-funds-key'},
          )).thenAnswer((_) async => http.Response('Payment Required', 402));

      expect(
        () => balanceClient.check('sk-or-vv-no-funds-key', ProviderType.vsegpt),
        throwsA(isA<InsufficientFundsError>()),
      );
    });

    test('throws InvalidKeyError on 401 status code', () async {
      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer invalid-key'},
          )).thenAnswer((_) async => http.Response('Unauthorized', 401));

      expect(
        () => balanceClient.check('invalid-key', ProviderType.vsegpt),
        throwsA(isA<InvalidKeyError>()),
      );
    });

    test('throws InvalidKeyError on 403 status code', () async {
      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer forbidden-key'},
          )).thenAnswer((_) async => http.Response('Forbidden', 403));

      expect(
        () => balanceClient.check('forbidden-key', ProviderType.vsegpt),
        throwsA(isA<InvalidKeyError>()),
      );
    });

    test('throws NetworkError on 429 status code', () async {
      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer sk-or-vv-test-key'},
          )).thenAnswer((_) async => http.Response('Too Many Requests', 429));

      expect(
        () => balanceClient.check('sk-or-vv-test-key', ProviderType.vsegpt),
        throwsA(isA<NetworkError>()),
      );
    });

    test('throws NetworkError on 500 status code', () async {
      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer sk-or-vv-test-key'},
          )).thenAnswer((_) async => http.Response('Server Error', 500));

      expect(
        () => balanceClient.check('sk-or-vv-test-key', ProviderType.vsegpt),
        throwsA(isA<NetworkError>()),
      );
    });

    test('throws BadResponseError when balance field not found', () async {
      final responseBody = jsonEncode({
        'error': 'No balance available',
      });

      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer sk-or-vv-test-key'},
          )).thenAnswer((_) async => http.Response(
            responseBody,
            200,
            headers: {'content-type': 'application/json'},
          ));

      expect(
        () => balanceClient.check('sk-or-vv-test-key', ProviderType.vsegpt),
        throwsA(isA<BadResponseError>()),
      );
    });

    test('throws BadResponseError on invalid JSON', () async {
      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer sk-or-vv-test-key'},
          )).thenAnswer((_) async => http.Response(
            'Not JSON',
            200,
            headers: {'content-type': 'application/json'},
          ));

      expect(
        () => balanceClient.check('sk-or-vv-test-key', ProviderType.vsegpt),
        throwsA(isA<BadResponseError>()),
      );
    });

    test('throws BadResponseError on HTML response', () async {
      when(() => mockClient.get(
            Uri.parse('https://api.vsetgpt.ru/v1/balance'),
            headers: {'Authorization': 'Bearer sk-or-vv-test-key'},
          )).thenAnswer((_) async => http.Response(
            '<html><body>Error page</body></html>',
            200,
            headers: {'content-type': 'text/html'},
          ));

      expect(
        () => balanceClient.check('sk-or-vv-test-key', ProviderType.vsegpt),
        throwsA(isA<BadResponseError>()),
      );
    });
  });
}
