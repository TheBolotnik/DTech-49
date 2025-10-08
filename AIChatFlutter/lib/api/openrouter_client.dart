// Import JSON library
import 'dart:convert';
// Import HTTP client
import 'package:http/http.dart' as http;
// Import Flutter core classes
import 'package:flutter/foundation.dart';
// Import package for working with .env files (legacy support for dev)
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Import auth components
import '../auth/credentials_repository.dart';
import '../auth/provider_detector.dart';
import '../auth/balance_types.dart';
import '../auth/balance_client.dart';
// Import logging utilities
import '../utils/log_safety.dart';
import '../utils/json_http.dart';
// Import models result
import 'models_result.dart';

/// API client for working with OpenRouter and VseGPT APIs
class OpenRouterClient {
  // Credentials repository for secure API key storage
  final CredentialsRepository? _credentialsRepo;

  // Base URLs by provider
  static const String _openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String _vseGptBaseUrl = 'https://api.vsetgpt.ru/v1';

  /// Constructor with optional credentials repository
  /// If repository is null, falls back to .env (for development only)
  OpenRouterClient({CredentialsRepository? credentialsRepository})
      : _credentialsRepo = credentialsRepository;

  /// Get the active API key from credentials repository
  /// SECURITY: No fallback to environment variables - credentials must come from repository
  Future<String> getActiveApiKey() async {
    // Log warning if env keys are detected (they will be ignored)
    if (kDebugMode && dotenv.env.containsKey('OPENROUTER_API_KEY')) {
      debugPrint(
          'WARNING: OPENROUTER_API_KEY found in .env but will be ignored. Use app credentials only.');
    }
    if (kDebugMode && dotenv.env.containsKey('VSEGPT_API_KEY')) {
      debugPrint(
          'WARNING: VSEGPT_API_KEY found in .env but will be ignored. Use app credentials only.');
    }

    // Credentials repository is required - no fallback
    if (_credentialsRepo == null) {
      throw Exception(
          'No credentials repository configured. Application must use secure credential storage.');
    }

    final credentials = await _credentialsRepo.read();
    if (credentials == null) {
      throw Exception(
          'No credentials found. Please configure API key in the application.');
    }

    return await _credentialsRepo.decryptApiKey(credentials);
  }

  /// Get the active base URL based on provider
  /// SECURITY: No fallback to environment variables - provider must come from repository
  Future<Uri> getActiveBaseUrl() async {
    // Credentials repository is required - no fallback
    if (_credentialsRepo == null) {
      throw Exception(
          'No credentials repository configured. Application must use secure credential storage.');
    }

    final credentials = await _credentialsRepo.read();
    if (credentials == null) {
      throw Exception(
          'No credentials found. Please configure API key in the application.');
    }

    switch (credentials.provider) {
      case ProviderType.openrouter:
        return Uri.parse(_openRouterBaseUrl);
      case ProviderType.vsegpt:
        return Uri.parse(_vseGptBaseUrl);
      case ProviderType.unknown:
        throw Exception('Unknown provider type');
    }
  }

  /// Get current provider type
  /// SECURITY: No fallback to environment variables - provider must come from repository
  Future<ProviderType> getActiveProvider() async {
    // Credentials repository is required - no fallback
    if (_credentialsRepo == null) {
      return ProviderType.unknown;
    }

    final credentials = await _credentialsRepo.read();
    if (credentials == null) {
      return ProviderType.unknown;
    }

    return credentials.provider;
  }

  /// Refresh credentials cache (reserved for future optimization)
  Future<void> refreshFromCredentials() async {
    // No-op for now - direct reads are fast enough
    // Future: Could cache decrypted keys for a short time
  }

  /// Resolve a path relative to a base URI
  /// Handles paths with or without leading slashes correctly
  Uri _resolve(Uri base, String path) {
    // Ensure base ends with / for proper path joining
    final baseStr = base.toString();
    final normalizedBase = baseStr.endsWith('/') ? baseStr : '$baseStr/';

    // Remove leading slash from path if present
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    return Uri.parse('$normalizedBase$cleanPath');
  }

  /// Build authorization headers with current API key
  Future<Map<String, String>> _buildHeaders(
      {bool includeContentType = true}) async {
    final apiKey = await getActiveApiKey();
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Accept': 'application/json',
      'Accept-Charset': 'utf-8',
      'X-Title': 'AI Chat Flutter',
    };

    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }

    return headers;
  }

  /// Log safely with masked API key
  void _logSafe(String message, {String? apiKey}) {
    if (kDebugMode) {
      if (apiKey != null) {
        print('$message (key: ${maskApiKey(apiKey)})');
      } else {
        print(message);
      }
    }
  }

  /// Get list of available models
  ///
  /// Returns [ModelsResult] with models list and fallback indicator.
  /// Only uses fallback when network errors or bad responses occur.
  Future<ModelsResult> getModels() async {
    try {
      final baseUrl = await getActiveBaseUrl();
      final headers = await _buildHeaders(includeContentType: false);
      final apiKey = await getActiveApiKey();
      final endpoint = _resolve(baseUrl, 'models');

      _logSafe('Fetching models from $endpoint', apiKey: apiKey);

      // Execute GET request to fetch models
      final response = await http.get(
        endpoint,
        headers: headers,
      );

      _logSafe('Models response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Use JSON validation utility to fail fast on HTML/non-JSON responses
        final json = parseJsonOrThrow(response);

        // Extract data array
        final list = (json['data'] as List?) ?? [];

        if (list.isEmpty) {
          // Show dedicated error for empty list instead of silent fallback
          _logSafe('API returned empty models list');
          return ModelsResult.fallback(
            _getDefaultModels(),
            'API returned no models',
          );
        }

        // Map models to internal format
        final models = list
            .map((model) => {
                  'id': model['id'] as String,
                  'name': (() {
                    try {
                      return utf8.decode((model['name'] as String).codeUnits);
                    } catch (e) {
                      // Remove invalid UTF-8 characters and try again
                      final cleaned = (model['name'] as String)
                          .replaceAll(RegExp(r'[^\x00-\x7F]'), '');
                      return utf8.decode(cleaned.codeUnits);
                    }
                  })(),
                  'pricing': {
                    'prompt': model['pricing']['prompt'] as String,
                    'completion': model['pricing']['completion'] as String,
                  },
                  'context_length': (model['context_length'] ??
                          model['top_provider']?['context_length'] ??
                          0)
                      .toString(),
                })
            .toList();

        _logSafe('Successfully fetched ${models.length} models from API');
        return ModelsResult.fromApi(models);
      } else {
        // Non-200 status code - use fallback
        final reason = 'HTTP ${response.statusCode}';
        _logSafe('Models fetch failed: $reason');
        return ModelsResult.fallback(_getDefaultModels(), reason);
      }
    } on BadResponseError catch (e) {
      // Bad response (e.g., HTML instead of JSON) - use fallback
      _logSafe('BadResponseError fetching models: $e');
      return ModelsResult.fallback(
        _getDefaultModels(),
        'Invalid response format: ${e.message}',
      );
    } catch (e) {
      // Network or other errors - use fallback
      _logSafe('Error fetching models: $e');
      return ModelsResult.fallback(
        _getDefaultModels(),
        'Network error: $e',
      );
    }
  }

  /// Get default models as fallback
  List<Map<String, dynamic>> _getDefaultModels() {
    return [
      {
        'id': 'deepseek-coder',
        'name': 'DeepSeek',
        'pricing': {
          'prompt': '0.00000014',
          'completion': '0.00000028',
        },
        'context_length': '128000',
      },
      {
        'id': 'claude-3-sonnet',
        'name': 'Claude 3.5 Sonnet',
        'pricing': {
          'prompt': '0.000003',
          'completion': '0.000015',
        },
        'context_length': '200000',
      },
      {
        'id': 'gpt-3.5-turbo',
        'name': 'GPT-3.5 Turbo',
        'pricing': {
          'prompt': '0.0000005',
          'completion': '0.0000015',
        },
        'context_length': '16385',
      },
    ];
  }

  /// Send message through API
  Future<Map<String, dynamic>> sendMessage(String message, String model) async {
    try {
      final baseUrl = await getActiveBaseUrl();
      final headers = await _buildHeaders();
      final apiKey = await getActiveApiKey();
      final endpoint = _resolve(baseUrl, 'chat/completions');

      // Prepare data for sending
      final data = {
        'model': model,
        'messages': [
          {'role': 'user', 'content': message}
        ],
        'max_tokens': int.parse(dotenv.env['MAX_TOKENS'] ?? '1000'),
        'temperature': double.parse(dotenv.env['TEMPERATURE'] ?? '0.7'),
        'stream': false,
      };

      _logSafe('Sending message to $endpoint', apiKey: apiKey);

      // Execute POST request
      final response = await http.post(
        endpoint,
        headers: headers,
        body: json.encode(data),
      );

      _logSafe('Message response status: ${response.statusCode}');

      // Use JSON validation utility to fail fast on HTML/non-JSON responses
      final responseData = parseJsonOrThrow(response);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        // Handle error responses - extract clean error message
        if (responseData.containsKey('error')) {
          final error = responseData['error'];
          String errorMessage;

          if (error is Map) {
            // OpenAI-style error: {"error": {"message": "...", "type": "...", "code": "..."}}
            errorMessage = error['message'] as String? ??
                error['code'] as String? ??
                'Unknown error occurred';
          } else if (error is String) {
            // Simple error: {"error": "error message"}
            errorMessage = error;
          } else {
            errorMessage = 'Unknown error occurred';
          }

          return {'error': errorMessage};
        }

        // No error field in response, return generic message
        return {
          'error':
              'HTTP ${response.statusCode}: ${response.reasonPhrase ?? "Unknown error"}'
        };
      }
    } on BadResponseError catch (e) {
      // Handle HTML or invalid JSON responses
      _logSafe('BadResponseError sending message: $e');
      return {'error': 'Invalid response from server: ${e.message}'};
    } catch (e) {
      _logSafe('Error sending message: $e');
      return {'error': e.toString()};
    }
  }

  /// Get current balance as BalanceStatus
  Future<BalanceStatus?> getBalance() async {
    try {
      final apiKey = await getActiveApiKey();
      final provider = await getActiveProvider();

      _logSafe('Fetching balance for provider: $provider', apiKey: apiKey);

      // Use the balance API to get structured balance data
      final client = balanceClientFactory();
      final status = await client.check(apiKey, provider);

      _logSafe(
          'Balance fetched successfully: ${status.value} ${status.currency}');
      return status;
    } catch (e) {
      _logSafe('Error getting balance: $e');
      return null;
    }
  }

  /// Format pricing based on provider
  Future<String> formatPricing(double pricing) async {
    try {
      final provider = await getActiveProvider();
      if (provider == ProviderType.vsegpt) {
        return '${pricing.toStringAsFixed(3)}₽/K';
      } else {
        return '\$${(pricing * 1000000).toStringAsFixed(3)}/M';
      }
    } catch (e) {
      _logSafe('Error formatting pricing: $e');
      return '0.00';
    }
  }
}
