class AuthException implements Exception {
  final String message;
  AuthException([this.message = 'Authentication error']);
  @override
  String toString() => 'AuthException: $message';
}

class InvalidCredentialsException extends AuthException {
  InvalidCredentialsException([super.message = 'Invalid credentials']);
}

class EmailAlreadyExistsException extends AuthException {
  EmailAlreadyExistsException([super.message = 'Email already exists']);
}

class WeakPasswordException extends AuthException {
  WeakPasswordException([super.message = 'Weak password']);
}

class NetworkException extends AuthException {
  NetworkException([super.message = 'Network error']);
}

class UnverifiedEmailException extends AuthException {
  UnverifiedEmailException([super.message = 'Email not verified']);
}
