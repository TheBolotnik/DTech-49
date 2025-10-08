/// Enum for supported AI provider types
enum ProviderType {
  openrouter,
  vsegpt,
  unknown,
}

/// Detects and validates AI provider credentials
class ProviderDetector {
  /// Minimum required API key length
  static const int minKeyLength = 16;

  /// Regular expression for valid API key characters
  static final RegExp _validCharacters = RegExp(r'^[A-Za-z0-9\-_]+$');

  /// OpenRouter API key prefix
  static const String _openRouterPrefix = 'sk-or-v1-';

  /// VseGPT API key prefix
  static const String _vseGptPrefix = 'sk-or-vv-';

  /// Validates the format of an API key
  ///
  /// Returns true if the key:
  /// - Has minimum required length (>= 16 characters)
  /// - Contains only valid characters: [A-Za-z0-9\-_]
  bool isFormatValid(String apiKey) {
    if (apiKey.length < minKeyLength) {
      return false;
    }

    return _validCharacters.hasMatch(apiKey);
  }

  /// Detects the provider type based on API key prefix
  ///
  /// Returns:
  /// - ProviderType.openrouter if key starts with 'sk-or-v1-'
  /// - ProviderType.vsegpt if key starts with 'sk-or-vv-'
  /// - ProviderType.unknown otherwise
  ProviderType detect(String apiKey) {
    if (!isFormatValid(apiKey)) {
      return ProviderType.unknown;
    }

    if (apiKey.startsWith(_openRouterPrefix)) {
      return ProviderType.openrouter;
    }

    if (apiKey.startsWith(_vseGptPrefix)) {
      return ProviderType.vsegpt;
    }

    return ProviderType.unknown;
  }

  /// Returns a user-friendly error message for invalid API keys
  String getErrorMessage() {
    return 'Неверный формат API-ключа: поддерживаются ключи вида sk-or-v1-… и sk-or-vv-…';
  }
}
