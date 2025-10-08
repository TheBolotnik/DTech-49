import 'provider_detector.dart';

/// Model class for storing encrypted application credentials
class AppCredentials {
  /// Provider type (openrouter, vsegpt, unknown)
  final ProviderType provider;

  /// Base64-encoded encrypted API key ciphertext
  final String apiKeyData;

  /// Base64-encoded MAC for API key
  final String apiKeyMac;

  /// Base64-encoded IV/nonce for API key encryption
  final String apiKeyIv;

  /// Base64-encoded PIN hash (SHA-256)
  final String pinHash;

  /// Base64-encoded PIN salt
  final String pinSalt;

  /// Currency code ('USD' or 'RUB')
  final String currency;

  /// Current balance value (nullable)
  final double? balanceValue;

  /// Timestamp when credentials were created
  final DateTime createdAt;

  /// Timestamp of last balance check
  final DateTime lastCheckAt;

  const AppCredentials({
    required this.provider,
    required this.apiKeyData,
    required this.apiKeyMac,
    required this.apiKeyIv,
    required this.pinHash,
    required this.pinSalt,
    required this.currency,
    required this.balanceValue,
    required this.createdAt,
    required this.lastCheckAt,
  });

  /// Convert credentials to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'provider': provider.name,
      'apiKeyData': apiKeyData,
      'apiKeyMac': apiKeyMac,
      'apiKeyIv': apiKeyIv,
      'pinHash': pinHash,
      'pinSalt': pinSalt,
      'currency': currency,
      'balanceValue': balanceValue,
      'createdAt': createdAt.toIso8601String(),
      'lastCheckAt': lastCheckAt.toIso8601String(),
    };
  }

  /// Create credentials from JSON
  factory AppCredentials.fromJson(Map<String, dynamic> json) {
    return AppCredentials(
      provider: ProviderType.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => ProviderType.unknown,
      ),
      apiKeyData: json['apiKeyData'] as String,
      apiKeyMac: json['apiKeyMac'] as String,
      apiKeyIv: json['apiKeyIv'] as String,
      pinHash: json['pinHash'] as String,
      pinSalt: json['pinSalt'] as String,
      currency: json['currency'] as String,
      balanceValue: json['balanceValue'] as double?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastCheckAt: DateTime.parse(json['lastCheckAt'] as String),
    );
  }

  /// Create a copy with updated fields
  AppCredentials copyWith({
    ProviderType? provider,
    String? apiKeyData,
    String? apiKeyMac,
    String? apiKeyIv,
    String? pinHash,
    String? pinSalt,
    String? currency,
    double? balanceValue,
    DateTime? createdAt,
    DateTime? lastCheckAt,
  }) {
    return AppCredentials(
      provider: provider ?? this.provider,
      apiKeyData: apiKeyData ?? this.apiKeyData,
      apiKeyMac: apiKeyMac ?? this.apiKeyMac,
      apiKeyIv: apiKeyIv ?? this.apiKeyIv,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      currency: currency ?? this.currency,
      balanceValue: balanceValue ?? this.balanceValue,
      createdAt: createdAt ?? this.createdAt,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
    );
  }
}
