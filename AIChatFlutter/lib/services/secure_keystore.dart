import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String masterKeyId = 'app_master_key_v1';

  Future<void> saveKey(String keyId, String value) async {
    await _storage.write(
      key: keyId,
      value: value,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      iOptions: const IOSOptions(),
    );
  }

  Future<String?> readKey(String keyId) async {
    return await _storage.read(
      key: keyId,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      iOptions: const IOSOptions(),
    );
  }

  Future<void> deleteKey(String keyId) async {
    await _storage.delete(
      key: keyId,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      iOptions: const IOSOptions(),
    );
  }

  /// Ensures a master key exists in secure storage.
  /// If absent, generates a new 32-byte key, base64-encodes it, and stores it.
  /// Returns the raw bytes (Uint8List) of the master key.
  Future<Uint8List> ensureMasterKey() async {
    // Try to read existing key
    String? existingKey = await readKey(masterKeyId);

    if (existingKey != null) {
      // Decode and return existing key
      return base64Decode(existingKey);
    }

    // Generate new 32-byte key
    final random = Random.secure();
    final keyBytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      keyBytes[i] = random.nextInt(256);
    }

    // Base64-encode and save
    final encodedKey = base64Encode(keyBytes);
    await saveKey(masterKeyId, encodedKey);

    return keyBytes;
  }
}
