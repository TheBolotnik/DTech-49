import 'package:flutter/foundation.dart';
import 'auth_state.dart';
import 'auth_service.dart';
import 'balance_types.dart';

/// Authentication provider for state management
class AuthProvider extends ChangeNotifier {
  final AuthService svc;
  AuthState state = AuthNoKey();

  AuthProvider(this.svc);

  /// Bootstrap authentication state on app start
  Future<void> bootstrap() async {
    final has = await svc.hasCredentials();
    state = has ? AuthPinRequired() : AuthNoKey();
    notifyListeners();
  }

  /// Submit API key for validation and storage
  Future<void> submitApiKey(String key) async {
    try {
      state = AuthCheckingKey();
      notifyListeners();
      final res = await svc.checkAndStoreKey(key);
      state = AuthPinSetup(res.pin);
      notifyListeners();
    } catch (e) {
      state = AuthError(_mapError(e));
      notifyListeners();
    }
  }

  /// Confirm that user has seen the PIN
  Future<void> confirmPinSeen() async {
    // After user saw the PIN, require PIN on next start
    state = AuthPinRequired();
    notifyListeners();
  }

  /// Enter PIN for authentication
  Future<void> enterPin(String pin) async {
    final ok = await svc.verifyPin(pin);
    state = ok ? AuthAuthorized() : AuthError('Неверный PIN');
    notifyListeners();
  }

  /// Reset all credentials
  Future<void> reset() async {
    await svc.reset();
    state = AuthNoKey();
    notifyListeners();
  }

  /// Map error to user-friendly message
  String _mapError(Object e) {
    if (e is BalanceError) {
      if (e is InvalidKeyError) {
        return 'Неверный или отозванный ключ.';
      } else if (e is InsufficientFundsError) {
        return 'Недостаточно средств / исчерпан лимит.';
      } else if (e is NetworkError) {
        return 'Сетевая ошибка. Попробуйте позже.';
      } else if (e is BadResponseError) {
        return 'Неожиданный ответ сервера.';
      }
    }
    return 'Произошла ошибка.';
  }
}
