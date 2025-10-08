/// Authentication state sealed class hierarchy
sealed class AuthState {}

/// No API key stored yet
class AuthNoKey extends AuthState {}

/// Checking API key validity
class AuthCheckingKey extends AuthState {}

/// PIN setup required - show generated PIN to user
class AuthPinSetup extends AuthState {
  final String pin;
  AuthPinSetup(this.pin);
}

/// PIN required for login
class AuthPinRequired extends AuthState {}

/// User is authorized
class AuthAuthorized extends AuthState {}

/// Error state with message
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
