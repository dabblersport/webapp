/// Custom exceptions for the application
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'AppException: $message';
}

class ValidationException extends AppException {
  ValidationException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'ValidationException: $message';
}

class AuthException extends AppException {
  AuthException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'AuthException: $message';
}

class ProfileException extends AppException {
  ProfileException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'ProfileException: $message';
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'NetworkException: $message';
}

class StorageException extends AppException {
  StorageException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'StorageException: $message';
}
