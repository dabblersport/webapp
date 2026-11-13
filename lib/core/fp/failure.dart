import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:equatable/equatable.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthApiException,
        AuthException,
        AuthRetryableFetchException,
        PostgrestException,
        StorageException;

/// One taxonomy for every repository (KAN-603): [noInternet], [timeout],
/// [server], [unauthenticated] and [unknown] are the shared classes; the other
/// values keep their meaning for finer cases. [network] and [unauthorized]
/// remain for older callers; new classification never produces [network].
enum FailureCode {
  unknown,
  network,
  noInternet,
  timeout,
  unauthenticated,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  capacityFull,
  waitlisted,
  rateLimited,
  server,
  cancelled,
}

class Failure extends Equatable {
  final FailureCode category;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  final String? code;
  final Map<String, dynamic>? details;

  const Failure({
    this.category = FailureCode.unknown,
    this.message = '',
    this.cause,
    this.stackTrace,
    this.code,
    this.details,
  });

  bool get isUnknown => category == FailureCode.unknown;
  bool get isNoInternet => category == FailureCode.noInternet;
  bool get isNetwork =>
      category == FailureCode.network || category == FailureCode.noInternet;
  bool get isTimeout => category == FailureCode.timeout;
  bool get isUnauthenticated => category == FailureCode.unauthenticated;
  bool get isUnauthorized =>
      category == FailureCode.unauthorized ||
      category == FailureCode.unauthenticated;
  bool get isForbidden => category == FailureCode.forbidden;
  bool get isNotFound => category == FailureCode.notFound;
  bool get isConflict => category == FailureCode.conflict;
  bool get isValidation => category == FailureCode.validation;
  bool get isServer => category == FailureCode.server;
  bool get isCancelled => category == FailureCode.cancelled;

  @override
  List<Object?> get props => [category, message, code, details, cause];

  @override
  String toString() => 'Failure($category, "$message")';

  /// Classifies [error] by its type and structured codes, never by searching
  /// its text, so native and web agree: a refused or dropped connection is
  /// [FailureCode.noInternet] whether it surfaces as a [SocketException]
  /// (native) or an http [ClientException] (web); a [TimeoutException] is
  /// [FailureCode.timeout]; status and Postgrest codes give
  /// [FailureCode.unauthenticated], forbidden, notFound, conflict or
  /// [FailureCode.server]; anything else is [FailureCode.unknown].
  static Failure from(Object error, [StackTrace? st]) {
    if (error is Failure) return error;
    final msg = error.toString();
    final FailureCode category = classifyError(error);
    return Failure(
      category: category,
      message: msg,
      cause: error,
      stackTrace: st,
    );
  }
}

/// The structured classification shared by [Failure.from] and
/// SupabaseErrorMapper (KAN-603).
FailureCode classifyError(Object error) {
  if (error is TimeoutException) return FailureCode.timeout;
  // Native refusal, web fetch failure, and a retryable auth fetch failure are
  // the same condition: the device could not reach the server.
  if (error is SocketException ||
      error is ClientException ||
      error is AuthRetryableFetchException) {
    return FailureCode.noInternet;
  }
  if (error is PostgrestException) return classifyStatusCode(error.code);
  if (error is AuthException) {
    return error is AuthApiException || error.statusCode != null
        ? classifyStatusCode(error.statusCode)
        : FailureCode.unknown;
  }
  if (error is StorageException) return classifyStatusCode(error.statusCode);
  return FailureCode.unknown;
}

/// An HTTP status or PostgREST/Postgres code to a taxonomy value. Unknown
/// codes from a responding server are [FailureCode.server].
FailureCode classifyStatusCode(String? code) {
  switch (code) {
    case null:
    case '':
      return FailureCode.unknown;
    case '401':
    case 'PGRST301':
    case 'PGRST302':
    case 'PGRST303':
      return FailureCode.unauthenticated;
    case '403':
    case '42501':
      return FailureCode.forbidden;
    case '404':
    case 'PGRST116':
      return FailureCode.notFound;
    case '408':
      return FailureCode.timeout;
    case '409':
    case '23505':
      return FailureCode.conflict;
    case '400':
    case '422':
    case '23502':
    case '23514':
      return FailureCode.validation;
    case '429':
      return FailureCode.rateLimited;
  }
  // 5xx and every other code a responding server returned.
  return FailureCode.server;
}

class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Authentication failed',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
    super.category = FailureCode.unauthorized,
  });
}

class UnauthenticatedFailure extends AuthFailure {
  const UnauthenticatedFailure({
    super.message = 'User not authenticated',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.unauthenticated);
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure({
    super.message = 'You do not have permission to perform this action',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.forbidden);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'Requested resource was not found',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.notFound);
}

class ValidationFailure extends Failure {
  final Map<String, List<String>>? fieldErrors;

  const ValidationFailure({
    super.message = 'Validation failed',
    this.fieldErrors,
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.validation);

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// The device could not reach the server ([FailureCode.noInternet]).
class NetworkFailure extends Failure {
  final int? status;

  const NetworkFailure({
    super.message = 'Network request failed',
    this.status,
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
    super.category = FailureCode.noInternet,
  });

  @override
  List<Object?> get props => [...super.props, status];
}

/// A request exceeded its wait: [FailureCode.timeout], not no-internet.
class TimeoutFailure extends NetworkFailure {
  const TimeoutFailure({
    super.message = 'The request timed out',
    super.status,
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.timeout);
}

class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Server error',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.server);
}

class DataFailure extends Failure {
  const DataFailure({
    super.message = 'Data operation failed',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.unknown);
}

class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Cache operation failed',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.unknown);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure({
    super.message = 'Database operation failed',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.server);
}

class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'You do not have permission to perform this action',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.forbidden);
}

class BusinessLogicFailure extends Failure {
  const BusinessLogicFailure({
    super.message = 'Business rule validation failed',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.validation);
}

class ConflictFailure extends Failure {
  const ConflictFailure({
    super.message = 'Resource conflict detected',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.conflict);
}

class FileUploadFailure extends Failure {
  const FileUploadFailure({
    super.message = 'Failed to upload file',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.server);
}

class FileDownloadFailure extends Failure {
  const FileDownloadFailure({
    super.message = 'Failed to download file',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.server);
}

class FileNotFoundFailure extends Failure {
  const FileNotFoundFailure({
    super.message = 'File not found',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.notFound);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    super.message = 'An unexpected error occurred',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.unknown);
}

class UnknownFailure extends Failure {
  final Object? error;

  const UnknownFailure({
    super.message = 'An unknown error occurred',
    this.error,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.unknown, cause: error);

  @override
  List<Object?> get props => [...super.props, error];
}

class SupabaseFailure extends Failure {
  const SupabaseFailure({
    super.message = 'Supabase request failed',
    super.code,
    super.details,
    super.cause,
    super.stackTrace,
  }) : super(category: FailureCode.server);
}

class SupabaseAuthFailure extends SupabaseFailure {
  const SupabaseAuthFailure({
    super.message = 'Supabase authentication failed',
    super.code,
    super.details,
    super.cause,
    super.stackTrace,
  });
}

class SupabaseAuthorizationFailure extends SupabaseFailure {
  const SupabaseAuthorizationFailure({
    super.message = 'You do not have access to this resource',
    super.code,
    super.details,
    super.cause,
    super.stackTrace,
  });
}

class SupabaseNotFoundFailure extends SupabaseFailure {
  const SupabaseNotFoundFailure({
    super.message = 'Supabase resource not found',
    super.code,
    super.details,
    super.cause,
    super.stackTrace,
  });
}

class SupabaseConflictFailure extends SupabaseFailure {
  const SupabaseConflictFailure({
    super.message = 'Supabase resource conflict',
    super.code,
    super.details,
    super.cause,
    super.stackTrace,
  });
}

class SupabaseValidationFailure extends SupabaseFailure {
  const SupabaseValidationFailure({
    super.message = 'Supabase validation error',
    super.details,
    super.code,
    super.cause,
    super.stackTrace,
  });
}
