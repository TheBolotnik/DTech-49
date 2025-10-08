import 'balance_client.dart';
import 'balance_types.dart';
import 'provider_detector.dart';

/// Flag to enable mock balance client (for offline demos)
const bool kUseMockBalance = true;

/// Mock implementation of BalanceClient for offline testing/demos
class MockBalanceClient implements BalanceClient {
  @override
  Future<BalanceStatus> check(String apiKey, ProviderType provider) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 150));

    switch (provider) {
      case ProviderType.openrouter:
        return BalanceStatus(
          isValidKey: true,
          hasPositiveBalance: true,
          currency: 'USD',
          value: 5.5,
          raw: {'mock': true, 'provider': 'openrouter'},
        );
      case ProviderType.vsegpt:
        return BalanceStatus(
          isValidKey: true,
          hasPositiveBalance: true,
          currency: 'RUB',
          value: 250.0,
          raw: {'mock': true, 'provider': 'vsegpt'},
        );
      default:
        throw const BadResponseError('Unknown provider');
    }
  }
}
