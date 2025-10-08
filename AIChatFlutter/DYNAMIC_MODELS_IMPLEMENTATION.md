# Dynamic Models Fetching Implementation

## Overview
Implemented dynamic model fetching from OpenRouter `/models` endpoint with proper error handling and fallback mode indication.

## Changes Made

### 1. Created ModelsResult Class (`lib/api/models_result.dart`)
- New class to wrap models list with fallback status
- Properties:
  - `models`: List of model data maps
  - `isFallback`: Boolean indicating if using fallback models
  - `fallbackReason`: Optional error message explaining why fallback was used
- Factory constructors:
  - `ModelsResult.fromApi()`: For successful API fetch
  - `ModelsResult.fallback()`: For fallback with error reason

### 2. Updated OpenRouterClient (`lib/api/openrouter_client.dart`)
- Changed `getModels()` return type from `List<Map<String, dynamic>>` to `Future<ModelsResult>`
- Improved error handling:
  - Properly extracts `data` array from JSON response
  - Shows dedicated error for empty models list instead of silent fallback
  - Only uses fallback when network errors or bad responses occur
  - Logs the number of models fetched from API
- Error handling hierarchy:
  1. HTTP 200 + valid JSON + non-empty data → Return API models
  2. HTTP 200 + valid JSON + empty data → Fallback with "API returned no models"
  3. HTTP non-200 → Fallback with status code
  4. BadResponseError (e.g., HTML instead of JSON) → Fallback with error details
  5. Network/other errors → Fallback with error message

### 3. Updated ChatProvider (`lib/providers/chat_provider.dart`)
- Added new state variables:
  - `_isModelsFallback`: Boolean flag for fallback mode
  - `_modelsFallbackReason`: String explaining why fallback was used
- Added getters:
  - `isModelsFallback`: Public getter for fallback status
  - `modelsFallbackReason`: Public getter for fallback reason
- Updated `_loadModels()`:
  - Handles `ModelsResult` instead of direct list
  - Extracts models, fallback status, and reason
  - Logs appropriate message based on fallback status

### 4. Updated Chat Screen UI (`lib/screens/chat_screen.dart`)
- Modified `_buildModelSelector()` to show fallback indicator
- Added orange warning icon next to model selector when in fallback mode
- Icon includes tooltip showing the fallback reason
- UI adjustments:
  - Reduced model selector width from 0.6 to 0.5 to make room for warning icon
  - Warning icon only shows when `chatProvider.isModelsFallback` is true

## Acceptance Criteria Verification

✅ **GET /models endpoint is called**: Implementation fetches from `{base}/models`

✅ **Response shape handled**: Code expects `{ "data": [ { "id": "...", ... }, ... ] }`

✅ **Maps to internal model DTOs**: Extracts `id`, `name`, `pricing` (prompt/completion), `context_length`

✅ **Empty list handling**: Shows dedicated "API returned no models" message and uses fallback

✅ **Fallback only on errors**: Uses fallback only when:
- Network errors occur
- BadResponseError (invalid JSON/HTML response)
- HTTP non-200 status codes
- Empty models list from API

✅ **UI marks fallback mode**: Orange warning icon with tooltip showing reason

✅ **Expanded models list**: On successful API fetch, models list will contain all models returned by OpenRouter (not limited to 3 hardcoded models)

## Benefits

1. **Dynamic Models**: App now uses real-time models from OpenRouter instead of hardcoded list
2. **Better Error Handling**: Clear distinction between network errors and API issues
3. **User Awareness**: Users can see when fallback models are being used and why
4. **Graceful Degradation**: App continues to work with fallback models when API is unavailable
5. **Improved Logging**: Better debug information about models loading status

## Testing Recommendations

1. **Normal Operation**:
   - Start app with valid API key
   - Verify models list contains more than 3 models (from actual API)
   - Verify no warning icon is shown
   - Check logs show: "Models loaded successfully from API (X models)"

2. **Network Error**:
   - Disconnect internet
   - Verify warning icon appears with appropriate message
   - Verify fallback models are available (3 hardcoded models)
   - Check logs show: "Models loaded in fallback mode: Network error: ..."

3. **Bad Response**:
   - Mock API to return HTML instead of JSON
   - Verify fallback is used with "Invalid response format" message
   - Verify warning icon shows the error

4. **Empty Models List**:
   - Mock API to return `{ "data": [] }`
   - Verify fallback with "API returned no models" message

## Files Modified

1. `lib/api/models_result.dart` - NEW
2. `lib/api/openrouter_client.dart` - Modified
3. `lib/providers/chat_provider.dart` - Modified
4. `lib/screens/chat_screen.dart` - Modified

## Migration Notes

- No breaking changes for existing functionality
- Fallback models are still available when API is unavailable
- Existing tests may need updates to handle `ModelsResult` instead of `List<Map>`
