import 'package:flutter_test/flutter_test.dart';
import 'package:ai_chat_flutter/auth/provider_detector.dart';

void main() {
  group('ProviderDetector', () {
    late ProviderDetector detector;

    setUp(() {
      detector = ProviderDetector();
    });

    group('isFormatValid', () {
      test('returns true for valid OpenRouter key', () {
        expect(detector.isFormatValid('sk-or-v1-1234567890abcdef'), true);
      });

      test('returns true for valid VseGPT key', () {
        expect(detector.isFormatValid('sk-or-vv-1234567890abcdef'), true);
      });

      test('returns true for key with valid characters', () {
        expect(
            detector.isFormatValid(
                'sk-or-v1-ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'),
            true);
      });

      test('returns false for key shorter than 16 characters', () {
        expect(detector.isFormatValid('sk-or-v1-short'), false);
      });

      test('returns false for key with spaces', () {
        expect(detector.isFormatValid('sk-or-v1-1234567890 abcdef'), false);
      });

      test('returns false for key with special characters', () {
        expect(detector.isFormatValid('sk-or-v1-1234567890@abcdef'), false);
        expect(detector.isFormatValid('sk-or-v1-1234567890#abcdef'), false);
        expect(detector.isFormatValid('sk-or-v1-1234567890!abcdef'), false);
      });

      test('returns false for empty string', () {
        expect(detector.isFormatValid(''), false);
      });
    });

    group('detect', () {
      test('detects OpenRouter provider', () {
        expect(detector.detect('sk-or-v1-1234567890abcdef'),
            ProviderType.openrouter);
        expect(detector.detect('sk-or-v1-very-long-key-with-more-characters'),
            ProviderType.openrouter);
      });

      test('detects VseGPT provider', () {
        expect(
            detector.detect('sk-or-vv-1234567890abcdef'), ProviderType.vsegpt);
        expect(detector.detect('sk-or-vv-very-long-key-with-more-characters'),
            ProviderType.vsegpt);
      });

      test('returns unknown for invalid format', () {
        expect(detector.detect('sk-or-v1-short'), ProviderType.unknown);
        expect(detector.detect('invalid-key-12345'), ProviderType.unknown);
        expect(detector.detect(''), ProviderType.unknown);
      });

      test('returns unknown for valid format but wrong prefix', () {
        expect(detector.detect('sk-openai-1234567890abcdef'),
            ProviderType.unknown);
        expect(
            detector.detect('api-key-1234567890abcdef'), ProviderType.unknown);
      });

      test('returns unknown for key with invalid characters', () {
        expect(detector.detect('sk-or-v1-1234567890@abcdef'),
            ProviderType.unknown);
        expect(detector.detect('sk-or-vv-1234567890 abcdef'),
            ProviderType.unknown);
      });
    });

    group('getErrorMessage', () {
      test('returns Russian error message', () {
        final message = detector.getErrorMessage();
        expect(message, contains('Неверный формат API-ключа'));
        expect(message, contains('sk-or-v1-'));
        expect(message, contains('sk-or-vv-'));
      });
    });
  });
}
