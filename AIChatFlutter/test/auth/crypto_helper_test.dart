import 'package:flutter_test/flutter_test.dart';
import 'package:ai_chat_flutter/auth/crypto_helper.dart';

void main() {
  group('CryptoHelper', () {
    test('hashPin and verifyPin returns true for correct PIN', () async {
      const pin = '1234';
      final hashed = await CryptoHelper.hashPin(pin);

      expect(hashed.containsKey('hash'), true);
      expect(hashed.containsKey('salt'), true);

      final verified = await CryptoHelper.verifyPin(
        pin,
        hashed['hash']!,
        hashed['salt']!,
      );

      expect(verified, true);
    });

    test('hashPin and verifyPin returns false for incorrect PIN', () async {
      const pin = '1234';
      const wrongPin = '5678';
      final hashed = await CryptoHelper.hashPin(pin);

      final verified = await CryptoHelper.verifyPin(
        wrongPin,
        hashed['hash']!,
        hashed['salt']!,
      );

      expect(verified, false);
    });

    test('encryptString and decryptString roundtrip equals original', () async {
      const plaintext = 'my-secret-api-key';
      final masterKey = CryptoHelper.randomBytes(32);

      final encrypted = await CryptoHelper.encryptString(plaintext, masterKey);

      expect(encrypted.containsKey('data'), true);
      expect(encrypted.containsKey('mac'), true);
      expect(encrypted.containsKey('iv'), true);

      final decrypted = await CryptoHelper.decryptString(encrypted, masterKey);

      expect(decrypted, plaintext);
    });

    test('randomBytes generates correct length', () {
      final bytes = CryptoHelper.randomBytes(16);
      expect(bytes.length, 16);
    });

    test('randomBytes generates different values', () {
      final bytes1 = CryptoHelper.randomBytes(16);
      final bytes2 = CryptoHelper.randomBytes(16);

      // With secure random, these should be different
      expect(bytes1, isNot(equals(bytes2)));
    });
  });
}
