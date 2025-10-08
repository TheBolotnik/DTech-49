/// Status of balance check for an API key
class BalanceStatus {
  /// Whether the API key is valid
  final bool isValidKey;

  /// Whether the balance is positive (has funds)
  final bool hasPositiveBalance;

  /// Currency code: "USD", "RUB", or "UNKNOWN"
  final String currency;

  /// Balance value:
  /// - For OpenRouter: limit_remaining
  /// - For VseGPT: balance
  /// - null if not available
  final double? value;

  /// Raw response data from the provider
  final Map<String, dynamic> raw;

  const BalanceStatus({
    required this.isValidKey,
    required this.hasPositiveBalance,
    required this.currency,
    required this.value,
    required this.raw,
  });
}

/// Base class for balance check errors
sealed class BalanceError {
  const BalanceError();
}

/// Error indicating the API key is invalid
class InvalidKeyError extends BalanceError {
  const InvalidKeyError();
}

/// Error indicating insufficient funds in the account
class InsufficientFundsError extends BalanceError {
  const InsufficientFundsError();
}

/// Error indicating a network-related problem
class NetworkError extends BalanceError {
  final String? message;

  const NetworkError([this.message]);
}

/// Error indicating a bad or unexpected response from the API
class BadResponseError extends BalanceError {
  final String? message;

  const BadResponseError([this.message]);
}

/// Error for any other unexpected issues
class UnknownError extends BalanceError {
  final String? message;

  const UnknownError([this.message]);
}
