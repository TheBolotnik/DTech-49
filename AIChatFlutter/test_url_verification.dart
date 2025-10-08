// ignore_for_file: avoid_print
// URL verification test - demonstrates correct endpoint building
import 'dart:io';

void main() {
  print('=== OpenRouter URL Building Verification ===\n');

  final baseUrl = Uri.parse('https://openrouter.ai/api/v1');

  // Helper function mimicking the _resolve method
  Uri resolve(Uri base, String path) {
    // Ensure base ends with / for proper path joining
    final baseStr = base.toString();
    final normalizedBase = baseStr.endsWith('/') ? baseStr : '$baseStr/';

    // Remove leading slash from path if present
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    return Uri.parse('$normalizedBase$cleanPath');
  }

  // Test endpoints
  final modelsEndpoint = resolve(baseUrl, 'models');
  final keyEndpoint = resolve(baseUrl, 'key');
  final chatEndpoint = resolve(baseUrl, 'chat/completions');

  print('Base URL: $baseUrl');
  print('');
  print('Endpoints:');
  print('  Models:  GET $modelsEndpoint');
  print('  Balance: GET $keyEndpoint');
  print('  Chat:    POST $chatEndpoint');
  print('');

  // Verify paths are correct
  final expectations = {
    'models': 'https://openrouter.ai/api/v1/models',
    'key': 'https://openrouter.ai/api/v1/key',
    'chat/completions': 'https://openrouter.ai/api/v1/chat/completions',
  };

  print('Verification:');
  var allPassed = true;

  if (modelsEndpoint.toString() == expectations['models']) {
    print('  ✓ Models endpoint correct');
  } else {
    print('  ✗ Models endpoint incorrect: $modelsEndpoint');
    allPassed = false;
  }

  if (keyEndpoint.toString() == expectations['key']) {
    print('  ✓ Key endpoint correct');
  } else {
    print('  ✗ Key endpoint incorrect: $keyEndpoint');
    allPassed = false;
  }

  if (chatEndpoint.toString() == expectations['chat/completions']) {
    print('  ✓ Chat endpoint correct');
  } else {
    print('  ✗ Chat endpoint incorrect: $chatEndpoint');
    allPassed = false;
  }

  print('');
  if (allPassed) {
    print('✓ All URL building tests passed!');
    exit(0);
  } else {
    print('✗ Some tests failed!');
    exit(1);
  }
}
