import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ai_chat_flutter/utils/json_http.dart';
import 'package:ai_chat_flutter/auth/balance_types.dart';

void main() {
  group('isJsonResponse', () {
    test('returns true for application/json content type', () {
      final response = http.Response(
        '{"test": "data"}',
        200,
        headers: {'content-type': 'application/json'},
      );
      expect(isJsonResponse(response), true);
    });

    test('returns true for application/json with charset', () {
      final response = http.Response(
        '{"test": "data"}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      expect(isJsonResponse(response), true);
    });

    test('returns false for text/html content type', () {
      final response = http.Response(
        '<html></html>',
        200,
        headers: {'content-type': 'text/html'},
      );
      expect(isJsonResponse(response), false);
    });

    test('returns false when content-type is missing', () {
      final response = http.Response('{"test": "data"}', 200);
      expect(isJsonResponse(response), false);
    });
  });

  group('parseJsonOrThrow', () {
    test('parses valid JSON with correct content-type', () {
      final response = http.Response(
        '{"data": {"value": 123}}',
        200,
        headers: {'content-type': 'application/json'},
      );
      final result = parseJsonOrThrow(response);
      expect(result, {
        'data': {'value': 123}
      });
    });

    test('throws BadResponseError on non-JSON content-type', () {
      final response = http.Response(
        '<html><body>Error page</body></html>',
        200,
        headers: {'content-type': 'text/html'},
      );
      expect(
        () => parseJsonOrThrow(response),
        throwsA(isA<BadResponseError>().having(
          (e) => e.message,
          'message',
          contains('Non-JSON response'),
        )),
      );
    });

    test('throws BadResponseError when body starts with HTML tag', () {
      final response = http.Response(
        '<html><body>Error</body></html>',
        200,
        headers: {'content-type': 'application/json'},
      );
      expect(
        () => parseJsonOrThrow(response),
        throwsA(isA<BadResponseError>().having(
          (e) => e.message,
          'message',
          contains('HTML response detected'),
        )),
      );
    });

    test('throws BadResponseError when body starts with DOCTYPE', () {
      final response = http.Response(
        '<!DOCTYPE html><html></html>',
        200,
        headers: {'content-type': 'application/json'},
      );
      expect(
        () => parseJsonOrThrow(response),
        throwsA(isA<BadResponseError>().having(
          (e) => e.message,
          'message',
          contains('HTML response detected'),
        )),
      );
    });

    test('throws BadResponseError with snippet on invalid JSON', () {
      final response = http.Response(
        'This is not JSON at all, just plain text that goes on and on',
        200,
        headers: {'content-type': 'application/json'},
      );
      expect(
        () => parseJsonOrThrow(response),
        throwsA(isA<BadResponseError>().having(
          (e) => e.message,
          'message',
          contains('Invalid JSON'),
        )),
      );
    });

    test('throws BadResponseError when JSON is not an object', () {
      final response = http.Response(
        '["array", "data"]',
        200,
        headers: {'content-type': 'application/json'},
      );
      expect(
        () => parseJsonOrThrow(response),
        throwsA(isA<BadResponseError>().having(
          (e) => e.message,
          'message',
          contains('Response is not a JSON object'),
        )),
      );
    });

    test('includes snippet limited to 200 characters in error message', () {
      final longHtml = '<html>' + 'x' * 300 + '</html>';
      final response = http.Response(
        longHtml,
        200,
        headers: {'content-type': 'text/html'},
      );

      try {
        parseJsonOrThrow(response);
        fail('Should have thrown BadResponseError');
      } catch (e) {
        expect(e, isA<BadResponseError>());
        final message = (e as BadResponseError).message!;
        // Extract the snippet part from the message
        final snippetStart = message.indexOf('<html>');
        final snippet = message.substring(snippetStart);
        // Verify snippet is limited to 200 chars
        expect(snippet.length, lessThanOrEqualTo(200));
      }
    });

    test('handles whitespace before HTML tags', () {
      final response = http.Response(
        '   \n  <html><body>Error</body></html>',
        200,
        headers: {'content-type': 'application/json'},
      );
      expect(
        () => parseJsonOrThrow(response),
        throwsA(isA<BadResponseError>()),
      );
    });
  });
}
