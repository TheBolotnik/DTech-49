/// Safe logging utilities to prevent secrets from leaking to logs or crash reports
library;

/// Masks an API key for safe logging.
///
/// Shows the first 6-8 characters and last 2-4 characters,
/// replacing the middle with asterisks.
///
/// Example:
/// - Input: "sk-or-v1-1234567890abcdef1234567890abcdef12345678"
/// - Output: "sk-or-v1-***...***5678"
///
/// For shorter keys (< 16 chars), masks everything except first 4 and last 2.
String maskApiKey(String key) {
  if (key.isEmpty) {
    return '(empty)';
  }

  // For very short keys (< 16 chars), show less
  if (key.length < 16) {
    if (key.length <= 6) {
      return '***${key.substring(key.length - 1)}';
    }
    final start = key.substring(0, 4);
    final end = key.substring(key.length - 2);
    return '$start***$end';
  }

  // For normal length keys, show more context
  // Determine how many chars to show at start
  int startChars = 8;

  // If key starts with a common prefix, show the whole prefix
  if (key.startsWith('sk-or-v1-')) {
    startChars = 9; // Show the full prefix
  } else if (key.startsWith('sk-')) {
    startChars = 8;
  }

  final start = key.substring(0, startChars.clamp(0, key.length));
  final endChars = key.length > 30 ? 4 : 2;
  final end = key.substring(key.length - endChars);

  return '$start***...***$end';
}

/// Masks sensitive credential fields for logging.
/// Never logs PIN hashes, salts, or decrypted API keys.
String maskCredentialInfo(Map<String, dynamic> info) {
  final safe = Map<String, dynamic>.from(info);

  // Remove or mask sensitive fields
  safe.remove('pinHash');
  safe.remove('pinSalt');
  safe.remove('apiKey');
  safe.remove('decryptedApiKey');

  // Mask encrypted data (show only that it exists)
  if (safe.containsKey('apiKeyData')) {
    safe['apiKeyData'] = '<encrypted>';
  }
  if (safe.containsKey('apiKeyMac')) {
    safe['apiKeyMac'] = '<mac>';
  }
  if (safe.containsKey('apiKeyIv')) {
    safe['apiKeyIv'] = '<iv>';
  }

  return safe.toString();
}
