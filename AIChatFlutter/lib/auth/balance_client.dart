import 'package:http/http.dart' as http;
import 'balance_types.dart';
import 'provider_detector.dart';
import 'balance_client_mock.dart';
import '../utils/json_http.dart';

/// Abstract client for checking API balance
abstract class BalanceClient {
  /// Check balance for the given API key and provider
  Future<BalanceStatus> check(String apiKey, ProviderType provider);
}

/// HTTP implementation of BalanceClient
class HttpBalanceClient implements BalanceClient {
  final http.Client _client;

  /// Creates an HttpBalanceClient with an optional custom HTTP client
  HttpBalanceClient([http.Client? client]) : _client = client ?? http.Client();

  @override
  Future<BalanceStatus> check(String apiKey, ProviderType provider) async {
    if (provider == ProviderType.openrouter) {
      return _checkOpenRouter(apiKey);
    } else if (provider == ProviderType.vsegpt) {
      return _checkVseGPT(apiKey);
    } else {
      throw const BadResponseError('Unknown provider');
    }
  }

  Future<BalanceStatus> _checkOpenRouter(String apiKey) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/key');
    final headers = {
      'Authorization': 'Bearer $apiKey',
    };

    try {
      final response = await _client.get(url, headers: headers);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const InvalidKeyError();
      }

      if (response.statusCode == 402) {
        throw const InsufficientFundsError();
      }

      if (response.statusCode == 429 || response.statusCode >= 500) {
        throw NetworkError('HTTP ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        // Use JSON validation utility to fail fast on HTML/non-JSON responses
        final json = parseJsonOrThrow(response);
        final data = json['data'] as Map<String, dynamic>?;
        final limitRemaining = data?['limit_remaining'] as double?;

        return BalanceStatus(
          isValidKey: true,
          hasPositiveBalance: limitRemaining == null || limitRemaining > 0,
          currency: 'USD',
          value: limitRemaining,
          raw: json,
        );
      }

      throw BadResponseError('Unexpected status code: ${response.statusCode}');
    } catch (e) {
      if (e is BalanceError) {
        rethrow;
      }
      throw NetworkError('Network error: $e');
    }
  }

  Future<BalanceStatus> _checkVseGPT(String apiKey) async {
    final url = Uri.parse('https://api.vsetgpt.ru/v1/balance');
    final headers = {
      'Authorization': 'Bearer $apiKey',
    };

    try {
      final response = await _client.get(url, headers: headers);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const InvalidKeyError();
      }

      if (response.statusCode == 402) {
        throw const InsufficientFundsError();
      }

      if (response.statusCode == 429 || response.statusCode >= 500) {
        throw NetworkError('HTTP ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        // Use JSON validation utility to fail fast on HTML/non-JSON responses
        final json = parseJsonOrThrow(response);

        // Try to extract balance from different possible keys
        double? balance;
        if (json.containsKey('balance')) {
          balance = (json['balance'] as num?)?.toDouble();
        } else if (json.containsKey('amount')) {
          balance = (json['amount'] as num?)?.toDouble();
        } else if (json.containsKey('credits')) {
          balance = (json['credits'] as num?)?.toDouble();
        }

        if (balance == null) {
          throw const BadResponseError('Balance field not found in response');
        }

        // Extract currency if present
        String currency = 'RUB';
        if (json.containsKey('currency') && json['currency'] is String) {
          currency = json['currency'] as String;
        }

        return BalanceStatus(
          isValidKey: true,
          hasPositiveBalance: balance > 0,
          currency: currency,
          value: balance,
          raw: json,
        );
      }

      throw BadResponseError('Unexpected status code: ${response.statusCode}');
    } catch (e) {
      if (e is BalanceError) {
        rethrow;
      }
      throw NetworkError('Network error: $e');
    }
  }
}

/// Factory function to create a BalanceClient
BalanceClient balanceClientFactory({http.Client? client}) {
  if (kUseMockBalance) {
    return MockBalanceClient();
  }
  return HttpBalanceClient(client ?? http.Client());
}
