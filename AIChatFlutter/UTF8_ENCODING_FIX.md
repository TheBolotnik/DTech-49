# UTF-8 Encoding Fix Summary

## Problem
JSON responses with non-ASCII characters (e.g., Cyrillic) were being parsed incorrectly due to potential charset mis-detection when using `response.body`, which relies on HTTP header charset information that may be missing or incorrect.

## Solution
Modified JSON parsing to use explicit UTF-8 decoding from `response.bodyBytes` to ensure reliable handling of non-ASCII content.

## Changes Made

### 1. lib/utils/json_http.dart

#### Modified `parseJsonOrThrow()` function:
- **Before**: Used `response.body` (charset from HTTP headers or default)
- **After**: Uses `utf8.decode(response.bodyBytes, allowMalformed: false)` for explicit UTF-8 decoding

#### Key improvements:
1. **Explicit UTF-8 decoding**: 
   ```dart
   final text = utf8.decode(response.bodyBytes, allowMalformed: false);
   final json = jsonDecode(text) as Map<String, dynamic>;
   ```

2. **Content-type validation** (already present):
   - Validates that response has `application/json` content-type
   - Throws `BadResponseError` if content-type is missing or incorrect

3. **Better error handling**:
   - Added `_extractSnippetFromBytes()` helper function
   - Provides UTF-8 decoded snippets in error messages
   - Falls back to hex representation for truly malformed data

#### Error handling flow:
```
1. Check content-type header → must be application/json
2. Decode bodyBytes as UTF-8 → strict validation
3. Check for HTML markers → detect error pages
4. Parse JSON → validate structure
```

### 2. lib/api/openrouter_client.dart

#### Modified `_buildHeaders()` method:
Added `'Accept-Charset': 'utf-8'` header to explicitly request UTF-8 responses:

```dart
final headers = {
  'Authorization': 'Bearer $apiKey',
  'Accept': 'application/json',
  'Accept-Charset': 'utf-8',  // NEW
  'X-Title': 'AI Chat Flutter',
};
```

## Benefits

1. **Reliable Cyrillic support**: Model names and content with Cyrillic characters parse correctly
2. **No mojibake**: UTF-8 enforcement prevents character corruption
3. **Early failure**: Strict UTF-8 validation catches encoding issues immediately
4. **Better error messages**: UTF-8 decoded snippets in error messages
5. **Consistent behavior**: Same encoding handling across all API responses

## Testing

All tests pass successfully:
- ✅ `test/utils/json_http_test.dart` (12 tests)
- ✅ `test/auth/openrouter_balance_client_test.dart` (10 tests)
- ✅ `test/auth/vsegpt_balance_client_test.dart` (14 tests)
- ✅ `test/auth/utf8_roundtrip_test.dart` (8 tests) - **NEW**

### UTF-8 Roundtrip Tests

New comprehensive tests verify Cyrillic content preservation:

1. **Cyrillic content survives through parseJsonOrThrow** - Verifies "Привет! Чем я могу вам помочь сегодня?" preserves exactly with no mojibake
2. **Multiple non-ASCII languages preserve correctly** - Tests Russian, Japanese, Chinese, Arabic, Korean, Greek, Hebrew, and emojis
3. **Mixed ASCII and Cyrillic content** - Validates "Hello Привет! How are you? Как дела?" preserves correctly
4. **Long Cyrillic text** - Tests full Russian alphabet and long paragraphs
5. **Cyrillic in nested JSON structures** - Verifies deep object trees with Cyrillic values
6. **UTF-8 decoding catches invalid bytes** - Ensures invalid UTF-8 throws BadResponseError
7. **Real-world API response simulation** - Tests typical OpenRouter chat completion with Cyrillic
8. **bodyBytes vs body encoding behavior** - Demonstrates why bodyBytes approach is necessary

## Affected Components

Since `parseJsonOrThrow()` is used throughout the codebase, this fix benefits:
- API model fetching (`OpenRouterClient.getModels()`)
- Chat completions (`OpenRouterClient.sendMessage()`)
- Balance checking (`HttpBalanceClient._checkOpenRouter()`, `_checkVseGPT()`)
- Any future code using `parseJsonOrThrow()`

## Technical Details

### Why bodyBytes instead of body?

The `http.Response` class provides two ways to access response content:
1. **`response.body`**: String decoded using charset from Content-Type header or platform default
2. **`response.bodyBytes`**: Raw byte array requiring explicit decoding

Using `bodyBytes` with explicit UTF-8 decoding ensures:
- Predictable behavior regardless of server headers
- Protection against missing or incorrect charset declarations
- Strict UTF-8 validation with `allowMalformed: false`

### Error snippet extraction

Two helper functions handle error message snippets:
```dart
// For already-decoded strings
String _extractSnippet(String body)

// For raw bytes (when UTF-8 decode fails before we get a string)
String _extractSnippetFromBytes(List<int> bodyBytes)
```

The `_extractSnippetFromBytes()` function:
1. Attempts UTF-8 decode with `allowMalformed: true` for error display
2. Falls back to hex representation if even lenient decoding fails
3. Limits output to 200 characters for readability

## Acceptance Criteria - PASSED ✅

- ✅ JSON with Cyrillic content parses reliably
- ✅ No FormatException on valid UTF-8 JSON
- ✅ No mojibake (character corruption)
- ✅ Content-type validation enforced
- ✅ Accept-Charset header sent in requests
- ✅ All existing tests pass

## Migration Notes

No breaking changes - this is a transparent improvement to existing functionality. All code using `parseJsonOrThrow()` automatically benefits from UTF-8 enforcement.
