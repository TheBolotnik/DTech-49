import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/balance_types.dart';

/// Utility functions for validating and parsing JSON HTTP responses

/// Check if a response has a JSON content type
bool isJsonResponse(http.Response response) {
  final contentType = response.headers['content-type']?.toLowerCase();
  return contentType?.contains('application/json') == true;
}

/// Parse JSON from response or throw BadResponseError with HTML snippet
///
/// This ensures we fail fast on HTML responses (like error pages)
/// and prevent PIN issuance on invalid responses.
/// Uses UTF-8 decoding from bodyBytes to prevent charset mis-detection.
Map<String, dynamic> parseJsonOrThrow(http.Response response) {
  // First check Content-Type header - must be application/json
  if (!isJsonResponse(response)) {
    final snippet = _extractSnippetFromBytes(response.bodyBytes);
    throw BadResponseError(
        'Non-JSON response (Content-Type: ${response.headers['content-type']}): $snippet');
  }

  // Decode response body as UTF-8 to prevent charset mis-detection
  final String text;
  try {
    text = utf8.decode(response.bodyBytes, allowMalformed: false);
  } catch (e) {
    final snippet = _extractSnippetFromBytes(response.bodyBytes);
    throw BadResponseError('Invalid UTF-8 encoding: $snippet (error: $e)');
  }

  // Check if body starts with HTML markers
  final trimmed = text.trimLeft();
  if (trimmed.startsWith('<') ||
      trimmed.toLowerCase().startsWith('<!doctype')) {
    final snippet = _extractSnippet(text);
    throw BadResponseError('HTML response detected: $snippet');
  }

  // Try to parse JSON
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw BadResponseError(
          'Response is not a JSON object: ${_extractSnippet(text)}');
    }
    return decoded;
  } catch (e) {
    if (e is BadResponseError) {
      rethrow;
    }
    final snippet = _extractSnippet(text);
    throw BadResponseError('Invalid JSON: $snippet (error: $e)');
  }
}

/// Extract first 200 characters from body for error messages
String _extractSnippet(String body) {
  final length = body.length.clamp(0, 200);
  return body.substring(0, length);
}

/// Extract first 200 characters from bodyBytes for error messages
String _extractSnippetFromBytes(List<int> bodyBytes) {
  try {
    // Try to decode as UTF-8 with malformed allowed for error display
    final decoded = utf8.decode(bodyBytes, allowMalformed: true);
    return _extractSnippet(decoded);
  } catch (e) {
    // If even lenient decoding fails, return hex representation
    final length = bodyBytes.length.clamp(0, 100);
    final bytes = bodyBytes.sublist(0, length);
    return 'Binary data: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}';
  }
}
