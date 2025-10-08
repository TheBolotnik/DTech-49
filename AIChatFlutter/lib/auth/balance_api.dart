import 'provider_detector.dart';
import 'balance_client.dart';
import 'balance_types.dart';

/// Checks the balance for a given API key
///
/// This function automatically detects the provider from the API key format
/// and validates it before making the balance check request.
///
/// Throws [BadResponseError] if the API key is empty or has invalid format.
Future<BalanceStatus> checkBalanceForApiKey(String apiKey) async {
  final key = apiKey.trim();

  if (key.isEmpty) {
    throw const BadResponseError('Empty API key');
  }

  final detector = ProviderDetector();
  final provider = detector.detect(key);

  if (provider == ProviderType.unknown || !detector.isFormatValid(key)) {
    throw const BadResponseError('Invalid API key format');
  }

  final client = balanceClientFactory();
  return client.check(key, provider);
}
