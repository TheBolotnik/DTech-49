import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ai_chat_flutter/utils/json_http.dart';
import 'package:ai_chat_flutter/auth/balance_types.dart';

/// Tests for UTF-8 encoding preservation through JSON parsing
void main() {
  group('UTF-8 Roundtrip Tests', () {
    test('Cyrillic content survives through parseJsonOrThrow', () async {
      // Expected Cyrillic response
      const cyrillicResponse = 'Привет! Чем я могу вам помочь сегодня?';

      // Build JSON response with Cyrillic content
      final jsonResponse = {
        'choices': [
          {
            'message': {'content': cyrillicResponse}
          }
        ],
        'usage': {'total_tokens': 5, 'prompt_tokens': 2, 'completion_tokens': 3}
      };

      // Convert to JSON string and then to UTF-8 bytes
      final jsonString = json.encode(jsonResponse);
      final bodyBytes = utf8.encode(jsonString);

      // Create mock response with proper headers and UTF-8 bytes
      final mockResponse = http.Response.bytes(
        bodyBytes,
        200,
        headers: {
          'content-type': 'application/json; charset=utf-8',
        },
      );

      // Parse using parseJsonOrThrow (which uses our UTF-8 fix)
      final parsed = parseJsonOrThrow(mockResponse);

      // Extract the content from parsed response
      final choices = parsed['choices'] as List;
      final message = choices[0]['message'] as Map<String, dynamic>;
      final content = message['content'] as String;

      // Verify Cyrillic content is preserved exactly
      expect(content, equals(cyrillicResponse),
          reason: 'Cyrillic content should be preserved without mojibake');

      // Verify no double-encoding occurred
      expect(content, isNot(contains('\\u')),
          reason: 'Content should not contain Unicode escape sequences');

      // Verify length is correct (Cyrillic chars count correctly)
      expect(content.length, equals(cyrillicResponse.length),
          reason: 'String length should match original');

      // Verify byte-level correctness
      final contentBytes = utf8.encode(content);
      expect(contentBytes, equals(utf8.encode(cyrillicResponse)),
          reason: 'UTF-8 bytes should match original');
    });

    test('Multiple non-ASCII languages preserve correctly', () async {
      const testStrings = [
        'Привет!', // Russian
        'Как дела?', // Russian
        'Спасибо', // Russian
        'До свидания', // Russian
        '日本語', // Japanese
        '中文', // Chinese
        'العربية', // Arabic
        '한국어', // Korean
        'Ελληνικά', // Greek
        'עברית', // Hebrew
        '🎉🎊😀', // Emojis
      ];

      for (final testString in testStrings) {
        // Build JSON with test string
        final jsonResponse = {
          'data': {'text': testString}
        };

        final jsonString = json.encode(jsonResponse);
        final bodyBytes = utf8.encode(jsonString);

        final mockResponse = http.Response.bytes(
          bodyBytes,
          200,
          headers: {'content-type': 'application/json'},
        );

        // Parse using parseJsonOrThrow
        final parsed = parseJsonOrThrow(mockResponse);
        final data = parsed['data'] as Map<String, dynamic>;
        final content = data['text'] as String;

        expect(content, equals(testString),
            reason: 'String "$testString" should be preserved exactly');

        // Verify byte-level correctness
        expect(utf8.encode(content), equals(utf8.encode(testString)),
            reason: 'UTF-8 bytes for "$testString" should match');
      }
    });

    test('Mixed ASCII and Cyrillic content preserves correctly', () async {
      const mixedContent =
          'Hello Привет! How are you? Как дела? 123 ABC йцукен';

      final jsonResponse = {
        'message': mixedContent,
      };

      final jsonString = json.encode(jsonResponse);
      final bodyBytes = utf8.encode(jsonString);

      final mockResponse = http.Response.bytes(
        bodyBytes,
        200,
        headers: {'content-type': 'application/json'},
      );

      final parsed = parseJsonOrThrow(mockResponse);
      final content = parsed['message'] as String;

      expect(content, equals(mixedContent),
          reason: 'Mixed content should be preserved exactly');

      // Verify no mojibake by checking specific Cyrillic characters
      expect(content, contains('Привет'),
          reason: 'Cyrillic word "Привет" should be intact');
      expect(content, contains('дела'),
          reason: 'Cyrillic word "дела" should be intact');
      expect(content, contains('йцукен'),
          reason: 'Cyrillic word "йцукен" should be intact');
    });

    test('Long Cyrillic text preserves correctly', () async {
      const longCyrillic = '''
Добрый день! Это тестовое сообщение содержит длинный текст на русском языке.
Мы проверяем, что все символы корректно сохраняются при передаче через JSON.
Важно убедиться, что нет проблем с кодировкой UTF-8 и что все буквы читаемы:
АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ
абвгдеёжзийклмнопрстуфхцчшщъыьэюя
Цифры: 0123456789
Знаки препинания: .,!?;:()[]{}
''';

      final jsonResponse = {'text': longCyrillic};
      final jsonString = json.encode(jsonResponse);
      final bodyBytes = utf8.encode(jsonString);

      final mockResponse = http.Response.bytes(
        bodyBytes,
        200,
        headers: {'content-type': 'application/json'},
      );

      final parsed = parseJsonOrThrow(mockResponse);
      final content = parsed['text'] as String;

      expect(content, equals(longCyrillic),
          reason: 'Long Cyrillic text should be preserved exactly');
    });

    test('Cyrillic in nested JSON structures', () async {
      final complexJson = {
        'user': {
          'name': 'Александр',
          'messages': [
            {'text': 'Привет!', 'timestamp': '2024-01-01'},
            {'text': 'Как дела?', 'timestamp': '2024-01-02'},
          ],
          'metadata': {
            'city': 'Москва',
            'country': 'Россия',
          }
        }
      };

      final jsonString = json.encode(complexJson);
      final bodyBytes = utf8.encode(jsonString);

      final mockResponse = http.Response.bytes(
        bodyBytes,
        200,
        headers: {'content-type': 'application/json'},
      );

      final parsed = parseJsonOrThrow(mockResponse);

      final user = parsed['user'] as Map<String, dynamic>;
      expect(user['name'], equals('Александр'));

      final messages = user['messages'] as List;
      expect((messages[0] as Map)['text'], equals('Привет!'));
      expect((messages[1] as Map)['text'], equals('Как дела?'));

      final metadata = user['metadata'] as Map<String, dynamic>;
      expect(metadata['city'], equals('Москва'));
      expect(metadata['country'], equals('Россия'));
    });

    test('UTF-8 decoding with allowMalformed: false catches invalid bytes', () {
      // Create invalid UTF-8 byte sequence
      final invalidBytes = [
        0x7B, 0x22, 0x74, 0x65, 0x78, 0x74, 0x22, 0x3A, 0x22, // {"text":"
        0xFF, 0xFE, 0xFD, // Invalid UTF-8 sequence
        0x22, 0x7D // "}
      ];

      final mockResponse = http.Response.bytes(
        invalidBytes,
        200,
        headers: {'content-type': 'application/json'},
      );

      // Should throw BadResponseError due to invalid UTF-8
      expect(
        () => parseJsonOrThrow(mockResponse),
        throwsA(isA<BadResponseError>()),
        reason: 'Invalid UTF-8 should throw BadResponseError',
      );
    });

    test('Real-world API response simulation with Cyrillic', () async {
      // Simulate typical OpenRouter API response with Cyrillic content
      final apiResponse = {
        'id': 'chatcmpl-123',
        'object': 'chat.completion',
        'created': 1677652288,
        'model': 'gpt-3.5-turbo',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content':
                  'Конечно! Я рад помочь вам с вашим вопросом. Чем я могу быть полезен сегодня?'
            },
            'finish_reason': 'stop'
          }
        ],
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 20,
          'total_tokens': 30
        }
      };

      final jsonString = json.encode(apiResponse);
      final bodyBytes = utf8.encode(jsonString);

      final mockResponse = http.Response.bytes(
        bodyBytes,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

      final parsed = parseJsonOrThrow(mockResponse);

      // Extract assistant's message
      final choices = parsed['choices'] as List;
      final message = choices[0]['message'] as Map<String, dynamic>;
      final content = message['content'] as String;

      // Verify the Cyrillic content is intact
      expect(
          content,
          equals(
              'Конечно! Я рад помочь вам с вашим вопросом. Чем я могу быть полезен сегодня?'));
      expect(content, contains('Конечно!'));
      expect(content, contains('помочь'));
      expect(content, contains('полезен'));
    });

    test('Comparison: bodyBytes vs body encoding behavior', () {
      const cyrillicText = 'Привет мир!';
      final jsonMap = {'message': cyrillicText};
      final jsonString = json.encode(jsonMap);
      final bodyBytes = utf8.encode(jsonString);

      // Our method: explicit UTF-8 from bodyBytes
      final mockResponse = http.Response.bytes(
        bodyBytes,
        200,
        headers: {'content-type': 'application/json'},
      );

      final parsed = parseJsonOrThrow(mockResponse);
      final content = parsed['message'] as String;

      // Verify it matches the original using our UTF-8 fix
      expect(content, equals(cyrillicText),
          reason: 'parseJsonOrThrow should preserve Cyrillic correctly');

      // Demonstrate that response.body WITHOUT charset header may have issues
      // This shows why our bodyBytes approach is necessary
      // Note: response.body defaults to latin1 when charset is not specified
      // which causes mojibake for non-ASCII characters
      if (!mockResponse.headers.containsKey('charset') &&
          !mockResponse.headers['content-type']!.contains('charset')) {
        // Without charset, response.body may be incorrectly decoded
        // Our parseJsonOrThrow fixes this by using bodyBytes + utf8.decode
        expect(parsed['message'], equals(cyrillicText),
            reason: 'Our fix should work even without charset header');
      }
    });
  });
}
