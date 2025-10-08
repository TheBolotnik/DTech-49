import 'dart:math';
import 'provider_detector.dart';
import 'balance_api.dart';
import 'balance_types.dart';
import 'app_credentials.dart';
import 'credentials_repository.dart';
import 'crypto_helper.dart';

/// Result of PIN setup after successful API key validation
class AuthResultPinSetup {
  final String pin;
  final ProviderType provider;

  AuthResultPinSetup(this.pin, this.provider);
}

/// Authentication service
class AuthService {
  final CredentialsRepository repo;

  AuthService(this.repo);

  /// Check API key validity, verify balance, generate PIN, and store credentials
  ///
  /// Returns [AuthResultPinSetup] with generated PIN and detected provider.
  ///
  /// Throws:
  /// - [BadResponseError] if API key is empty or has invalid format
  /// - [InvalidKeyError] if API key is not valid
  /// - [InsufficientFundsError] if balance is zero or negative
  /// - [NetworkError] or other errors from balance check
  Future<AuthResultPinSetup> checkAndStoreKey(String apiKey) async {
    final key = apiKey.trim();

    if (key.isEmpty) {
      throw const BadResponseError('Empty API key');
    }

    final detector = ProviderDetector();
    final provider = detector.detect(key);

    if (provider == ProviderType.unknown || !detector.isFormatValid(key)) {
      throw const BadResponseError('Invalid API key format');
    }

    // Check balance - throws on errors
    final status = await checkBalanceForApiKey(key);

    if (!status.isValidKey) {
      throw const InvalidKeyError();
    }

    if (!status.hasPositiveBalance) {
      throw const InsufficientFundsError();
    }

    // Generate PIN (0000..9999), allow leading zeros
    final pin = (Random.secure().nextInt(10000)).toString().padLeft(4, '0');
    final pinMap = await CryptoHelper.hashPin(pin);
    final enc = await repo.encryptApiKey(key);

    final creds = AppCredentials(
      provider: provider,
      apiKeyData: enc['data']!,
      apiKeyMac: enc['mac']!,
      apiKeyIv: enc['iv']!,
      pinHash: pinMap['hash']!,
      pinSalt: pinMap['salt']!,
      currency: status.currency.isEmpty ? 'UNKNOWN' : status.currency,
      balanceValue: status.value,
      createdAt: DateTime.now(),
      lastCheckAt: DateTime.now(),
    );

    await repo.save(creds);
    return AuthResultPinSetup(pin, provider);
  }

  /// Verify PIN against stored credentials
  ///
  /// Returns true if PIN matches, false otherwise or if no credentials exist
  Future<bool> verifyPin(String input) async {
    final creds = await repo.read();
    if (creds == null) return false;
    return CryptoHelper.verifyPin(input, creds.pinHash, creds.pinSalt);
  }

  /// Reset all stored credentials
  Future<void> reset() async {
    await repo.clear();
  }

  /// Check if credentials are stored
  Future<bool> hasCredentials() async {
    return (await repo.read()) != null;
  }
}
