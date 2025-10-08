# Reset Flow Verification Report

## Overview
This document verifies that the reset functionality properly wipes encrypted credentials, PIN, and cached state, then routes to ApiKeyScreen.

## Requirements Verification

### ✅ 1. DatabaseService.clearCredentials() Deletes Stored JSON
**Location**: `lib/services/database_service.dart`

```dart
Future<void> clearCredentials() async {
  try {
    final db = await database;
    await db.delete(
      'app_credentials',
      where: 'key = ?',
      whereArgs: ['app_credentials'],
    );
  } catch (e) {
    debugPrint('Error clearing credentials: $e');
    rethrow;
  }
}
```

**Verified**: ✅ The method properly deletes the stored JSON from the SQLite database.

### ✅ 2. SecureKeyStore Master Key is PRESERVED
**Location**: `lib/services/secure_keystore.dart`

**Analysis**: The SecureKeyStore only has methods to:
- `ensureMasterKey()` - Creates or retrieves master key
- `saveKey()` - Saves keys
- `readKey()` - Reads keys
- `deleteKey()` - Deletes specific keys

**Verified**: ✅ The reset flow does NOT call `deleteKey(masterKeyId)`, so the master key is preserved. This is intentional to avoid requiring re-permissions on subsequent API key setups.

### ✅ 3. Reset Flow Chain

**Flow**: `PinLoginScreen` → `AuthProvider.reset()` → `AuthService.reset()` → `CredentialsRepository.clear()` → `DatabaseService.clearCredentials()`

1. **PinLoginScreen** (`lib/screens/pin_login_screen.dart`):
   ```dart
   Future<void> _reset() async {
     final confirmed = await showDialog<bool>(...);
     if (confirmed == true && mounted) {
       await context.read<AuthProvider>().reset();
     }
   }
   ```

2. **AuthProvider** (`lib/auth/auth_provider.dart`):
   ```dart
   Future<void> reset() async {
     await svc.reset();
     state = AuthNoKey();
     notifyListeners();
   }
   ```

3. **AuthService** (`lib/auth/auth_service.dart`):
   ```dart
   Future<void> reset() async {
     await repo.clear();
   }
   ```

4. **CredentialsRepository** (`lib/auth/credentials_repository.dart`):
   ```dart
   Future<void> clear() async {
     await _db.clearCredentials();
   }
   ```

**Verified**: ✅ Complete chain properly executes and wipes all credentials.

### ✅ 4. State Transitions to AuthNoKey

**Location**: `lib/auth/auth_provider.dart`

```dart
Future<void> reset() async {
  await svc.reset();
  state = AuthNoKey();  // <-- Transitions to AuthNoKey
  notifyListeners();
}
```

**Verified**: ✅ After reset, state is set to `AuthNoKey`.

### ✅ 5. Navigation to ApiKeyScreen

**Location**: `lib/main.dart` - AuthNavigator widget

```dart
return Consumer<AuthProvider>(
  builder: (context, authProvider, child) {
    final state = authProvider.state;
    if (state is AuthNoKey) {
      return const ApiKeyScreen();  // <-- Routes here after reset
    }
    // ... other states
  },
);
```

**Verified**: ✅ When state is `AuthNoKey`, the app displays `ApiKeyScreen`.

### ✅ 6. API Client Cache Clearing

**Location**: `lib/api/openrouter_client.dart`

**Analysis**: The OpenRouterClient:
- Does NOT cache decrypted API keys
- Reads credentials fresh on each request via `getActiveApiKey()`
- Has a no-op method `refreshFromCredentials()` for future optimization
- Does NOT maintain any state that needs clearing

```dart
Future<String> getActiveApiKey() async {
  if (_credentialsRepo != null) {
    final credentials = await _credentialsRepo.read();  // Fresh read each time
    if (credentials == null) {
      throw Exception('No credentials found. Please configure API key.');
    }
    return await _credentialsRepo.decryptApiKey(credentials);
  }
  // ...
}
```

**Verified**: ✅ No API client caches need to be cleared.

### ✅ 7. Previous PIN No Longer Works

**Test**: `test/auth/reset_flow_test.dart` - Lines 125-129

```dart
// STEP 9: Verify previous PIN no longer works
await authProvider.enterPin(originalPin);
expect(authProvider.state, isA<AuthError>());
final errorState = authProvider.state as AuthError;
expect(errorState.message, contains('Неверный PIN'));
```

**Verified**: ✅ After reset, the previous PIN returns an error.

## Test Results

All integration tests passed successfully:

```
✓ Complete reset flow: setup -> reset -> verify clean state
✓ Reset when no credentials exist should succeed  
✓ Reset clears all credential fields from database
✓ Multiple resets should not cause errors
✓ Reset preserves master key for subsequent encryptions
```

### Test Coverage

The comprehensive integration test (`test/auth/reset_flow_test.dart`) verifies:

1. ✅ Initial state is `AuthNoKey`
2. ✅ Can setup credentials with API key
3. ✅ Transitions to `AuthPinSetup` with generated PIN
4. ✅ Credentials are stored in database
5. ✅ Master key is created
6. ✅ PIN verification works before reset
7. ✅ **Reset executes successfully**
8. ✅ **State transitions to `AuthNoKey` after reset**
9. ✅ **Credentials are wiped from database**
10. ✅ **Master key is preserved (not deleted)**
11. ✅ **Previous PIN no longer works**
12. ✅ **hasCredentials() returns false**
13. ✅ **Can setup new credentials after reset**
14. ✅ New credentials use different PIN

## Data Flow Diagram

```
┌─────────────────┐
│ PinLoginScreen  │
│ "Сбросить ключ" │
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│ AuthProvider.reset()│
│ - Calls svc.reset() │
│ - Sets AuthNoKey    │
│ - Notifies listeners│
└────────┬────────────┘
         │
         ▼
┌──────────────────────┐
│ AuthService.reset()  │
│ - Calls repo.clear() │
└────────┬─────────────┘
         │
         ▼
┌───────────────────────────┐
│ CredentialsRepository     │
│ .clear()                  │
│ - Calls _db.clear...()    │
└────────┬──────────────────┘
         │
         ▼
┌────────────────────────────┐
│ DatabaseService            │
│ .clearCredentials()        │
│ - DELETE from DB           │
│ - Removes encrypted key    │
│ - Removes PIN hash/salt    │
│ - Removes all app_creds    │
└────────────────────────────┘

         │
         ▼
┌────────────────────────────┐
│ SecureKeyStore             │
│ - Master key PRESERVED ✓   │
│ - NOT deleted              │
└────────────────────────────┘

         │
         ▼
┌────────────────────────────┐
│ AuthNavigator in main.dart │
│ - Observes AuthNoKey       │
│ - Routes to ApiKeyScreen   │
└────────────────────────────┘
```

## Acceptance Criteria

### ✅ All Requirements Met

| Requirement | Status | Details |
|-------------|--------|---------|
| Reset button on PinLoginScreen | ✅ | Confirmation dialog → AuthProvider.reset() |
| AuthProvider.reset() executes | ✅ | Calls AuthService.reset() |
| DatabaseService.clearCredentials() | ✅ | Deletes stored JSON from SQLite |
| Master key preserved | ✅ | SecureKeyStore NOT cleared |
| API client caches cleared | ✅ | No caches exist (reads fresh each time) |
| State transitions to AuthNoKey | ✅ | AuthProvider sets state = AuthNoKey() |
| Routes to ApiKeyScreen | ✅ | AuthNavigator displays ApiKeyScreen |
| Previous PIN rejected | ✅ | Returns AuthError with "Неверный PIN" |

## Conclusion

**STATUS**: ✅ **VERIFIED - ALL REQUIREMENTS MET**

The reset functionality is **fully implemented and working correctly**:

1. ✅ "Сбросить ключ" button on PinLoginScreen executes AuthProvider.reset()
2. ✅ DatabaseService.clearCredentials() properly deletes stored JSON
3. ✅ SecureKeyStore master key is PRESERVED (not deleted)
4. ✅ API client has no caches to clear (reads credentials fresh)
5. ✅ After reset, app shows ApiKeyScreen
6. ✅ Previous PIN no longer works

**No changes are required** - the implementation already meets all acceptance criteria.
