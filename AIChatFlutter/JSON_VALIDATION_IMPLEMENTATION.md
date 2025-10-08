# JSON Content-Type Validation Implementation

## Overview

This implementation enforces strict JSON Content-Type validation and fails fast on HTML responses to prevent PIN issuance on invalid API responses.

## Problem Statement

Previously, when receiving an HTML error page (e.g., from a proxy or error page) instead of JSON, the app would attempt to parse it, potentially fail silently, and in some cases could proceed to generate a PIN even though the API key validation had not succeeded properly.

## Solution

### 1. Created JSON Validation Utility (`lib/utils/json_http.dart`)

A centralized utility module with two key functions:

- **`isJsonResponse(Response r)`**: Checks if the response has `application/json` content-type header
- **`parseJsonOrThrow(Response r)`**: Validates and parses JSON responses with multiple safety checks:
  1. Verifies Content-Type header is `application/json`
  2. Checks if response body starts with HTML markers (`<` or `<!DOCTYPE`)
  3. Attempts to parse JSON and validates it's a Map object
  4. Throws `BadResponseError` with a 200-character snippet of the response body for debugging

### 2. Updated Balance Clients

Modified `lib/auth/balance_client.dart` to use `parseJsonOrThrow()` in both:
- `_checkOpenRouter()`: OpenRouter API balance checking
- `_checkVseGPT()`: VseGPT API balance checking

**Benefits**:
- Eliminates manual HTML detection code duplication
- Provides consistent error messages with helpful snippets
- Automatically fails fast before attempting to extract balance data

### 3. Updated OpenRouter Client

Modified `lib/api/openrouter_client.dart` to use `parseJsonOrThrow()` in:
- `getModels()`: Model list fetching
- `sendMessage()`: Chat completion requests
- `getBalance()`: Balance checking

**Error Handling**:
- Success responses (200): Use `parseJsonOrThrow()` to validate JSON
- Error responses: Attempt to parse JSON, fall back to generic error message if not valid JSON

### 4. Error Propagation

The implementation ensures `BadResponseError` propagates correctly through the auth flow:

```
parseJsonOrThrow() 
  → HttpBalanceClient.check()
    → checkBalanceForApiKey()
      → AuthService.checkAndStoreKey()
        → User sees error (NO PIN GENERATED)
```

## Testing

### New Tests (`test/utils/json_http_test.dart`)

Comprehensive test coverage for the JSON validation utility:
- ✅ Validates correct content-type detection
- ✅ Detects HTML responses (even with JSON content-type header)
- ✅ Handles malformed JSON
- ✅ Validates snippet length limiting (200 chars)
- ✅ Handles whitespace before HTML tags

### Updated Existing Tests

Both balance client test files were updated to include proper `content-type` headers in mock responses:
- ✅ `test/auth/openrouter_balance_client_test.dart`: 10 tests passing
- ✅ `test/auth/vsegpt_balance_client_test.dart`: 14 tests passing
- ✅ Added new test cases for HTML response detection

## Acceptance Criteria - Met ✅

1. **If response Content-Type is not JSON or body doesn't start like JSON, throw BadResponseError with short HTML snippet (first 200 chars)** 
   - ✅ Implemented in `parseJsonOrThrow()`
   - ✅ Checks both Content-Type header and body content
   - ✅ Provides 200-character snippet in error message

2. **This must prevent PIN issuance on invalid responses**
   - ✅ `BadResponseError` is thrown before PIN generation
   - ✅ Error propagates through entire auth flow
   - ✅ AuthService never reaches PIN generation code on bad responses

3. **With deliberately bad key or HTML response, app shows a friendly error and DOES NOT generate PIN**
   - ✅ BadResponseError thrown with descriptive message
   - ✅ No silent failures or catches that suppress the error
   - ✅ PIN generation code only reached after successful validation

## Files Modified

1. **Created**:
   - `lib/utils/json_http.dart` - JSON validation utility
   - `test/utils/json_http_test.dart` - Comprehensive tests

2. **Updated**:
   - `lib/auth/balance_client.dart` - Use parseJsonOrThrow()
   - `lib/api/openrouter_client.dart` - Use parseJsonOrThrow()
   - `test/auth/openrouter_balance_client_test.dart` - Add content-type headers
   - `test/auth/vsegpt_balance_client_test.dart` - Add content-type headers

## Example Error Messages

### HTML Response
```
BadResponseError: HTML response detected: <html><head><title>Error</title></head><body>...</body></html>
```

### Wrong Content-Type
```
BadResponseError: Non-JSON response (Content-Type: text/html): <html><body>Error page</body></html>
```

### Invalid JSON
```
BadResponseError: Invalid JSON: This is not valid JSON text... (error: FormatException: ...)
```

## Security & Reliability Improvements

1. **Fail-Fast Approach**: Errors are detected immediately, preventing downstream issues
2. **No Silent Failures**: All errors are properly propagated with descriptive messages
3. **Debug Information**: 200-character snippets help diagnose issues in production
4. **Consistent Validation**: Single source of truth for JSON validation logic
5. **Content-Type Enforcement**: Prevents processing of non-JSON responses as JSON

## Future Considerations

- The 200-character snippet limit is configurable in `_extractSnippet()` if needed
- Content-Type checking is case-insensitive and supports charset specifications
- The utility can be extended to support other response validations if needed
