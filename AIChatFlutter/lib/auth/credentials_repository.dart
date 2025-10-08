import '../services/database_service.dart';
import '../services/secure_keystore.dart';
import 'crypto_helper.dart';
import 'app_credentials.dart';

/// Repository for managing encrypted application credentials
class CredentialsRepository {
  final DatabaseService _db;
  final SecureKeyStore _ks;

  CredentialsRepository(this._db, this._ks);

  /// Save credentials to database
  Future<void> save(AppCredentials credentials) async {
    await _db.saveCredentials(credentials.toJson());
  }

  /// Read credentials from database
  Future<AppCredentials?> read() async {
    final json = await _db.readCredentials();
    if (json == null) return null;
    return AppCredentials.fromJson(json);
  }

  /// Clear credentials from database
  Future<void> clear() async {
    await _db.clearCredentials();
  }

  /// Encrypt an API key using the master key from SecureKeyStore
  ///
  /// Returns a map with 'data', 'mac', and 'iv' fields (all base64-encoded)
  Future<Map<String, String>> encryptApiKey(String apiKey) async {
    final masterKey = await _ks.ensureMasterKey();
    return await CryptoHelper.encryptString(apiKey, masterKey);
  }

  /// Decrypt an API key from AppCredentials using the master key
  ///
  /// Returns the original plaintext API key
  Future<String> decryptApiKey(AppCredentials credentials) async {
    final masterKey = await _ks.ensureMasterKey();
    final encryptedData = {
      'data': credentials.apiKeyData,
      'mac': credentials.apiKeyMac,
      'iv': credentials.apiKeyIv,
    };
    return await CryptoHelper.decryptString(encryptedData, masterKey);
  }
}
