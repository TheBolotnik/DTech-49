import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoHelper {
  static final AesGcm _aes = AesGcm.with256bits();
  static final Sha256 _sha = Sha256();
  static final _rand = Random.secure();

  static Uint8List randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _rand.nextInt(256);
    }
    return b;
  }

  // Encrypt plaintext with AES-GCM using masterKey bytes.
  static Future<Map<String, String>> encryptString(
      String plaintext, Uint8List masterKey) async {
    final secretKey = SecretKey(masterKey);
    final nonce = randomBytes(12);
    final result = await _aes.encrypt(utf8.encode(plaintext),
        secretKey: secretKey, nonce: nonce);
    // result.cipherText + result.mac.bytes
    final data = base64Encode(result.cipherText);
    final mac = base64Encode(result.mac.bytes);
    final iv = base64Encode(nonce);
    return {'data': data, 'mac': mac, 'iv': iv};
  }

  static Future<String> decryptString(
      Map<String, String> enc, Uint8List masterKey) async {
    final secretKey = SecretKey(masterKey);
    final cipher = base64Decode(enc['data']!);
    final mac = Mac(base64Decode(enc['mac']!));
    final iv = base64Decode(enc['iv']!);
    final clear = await _aes.decrypt(SecretBox(cipher, nonce: iv, mac: mac),
        secretKey: secretKey);
    return utf8.decode(clear);
  }

  // Hash PIN with salt (SHA-256).
  static Future<Map<String, String>> hashPin(String pin) async {
    final salt = randomBytes(16);
    final bytes = utf8.encode('$pin:${base64Encode(salt)}');
    final digest = await _sha.hash(bytes);
    return {'hash': base64Encode(digest.bytes), 'salt': base64Encode(salt)};
  }

  static Future<bool> verifyPin(
      String pin, String hashB64, String saltB64) async {
    final bytes = utf8.encode('$pin:$saltB64');
    final digest = await _sha.hash(bytes);
    return base64Encode(digest.bytes) == hashB64;
  }
}
