import 'package:equatable/equatable.dart';

enum FailureCode {
  unknown,
  network,
  timeout,
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
  bool get isNetwork => category == FailureCode.network;
  bool get isTimeout => category == FailureCode.timeout;
  bool get isUnauthorized => category == FailureCode.unauthorized;
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

  static Failure from(Object error, [StackTrace? st]) {
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('Network')) {
      return Failure(
        category: FailureCode.network,
        message: msg,
        cause: error,
        stackTrace: st,
      );
    }
    if (msg.contains('Timeout')) {
      return Failure(
        category: FailureCode.timeout,
        message: msg,
        cause: error,
        stackTrace: st,
      );
    }
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return Failure(
        category: FailureCode.unauthorized,
        message: msg,
        cause: error,
        stackTrace: st,
      );
    }
    if (msg.contains('403') || msg.contains('forbidden')) {
      return Failure(
        category: FailureCode.forbidden,
        message: msg,
        cause: error,
        stackTrace: st,
      );
    }
    if (msg.contains('404') || msg.contains('not found')) {
      return Failure(
        category: FailureCode.notFound,
        message: msg,
        cause: error,
        stackTrace: st,
      );
    }
    if (msg.contains('409') || msg.contains('conflict')) {
      return Failure(
        category: FailureCode.conflict,
        message: msg,
        cause: error,
        stackTrace: st,
      );
    }
    if (msg.contains('validation')) {
      return Failure(
        category: FailureCode.validation,
        message: msg,
        cause: error,
        stackTrace: st,
      );
    }
    if (msg.contains('cancelled') || msg.contains('canceled')) {
      return Failure(
        category: FailureCode.cancelled,
        message: msg,
        cause: error,
        stackTrace: st,
      );
    }
    return Failure(
      category: FailureCode.unknown,
      message: msg,
      cause: error,
      stackTrace: st,
    );
  }
}

class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Authentication failed',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.unauthorized);
}

class UnauthenticatedFailure extends AuthFailure {
  const UnauthenticatedFailure({
    super.message = 'User not authenticated',
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  });
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

class NetworkFailure extends Failure {
  final int? status;

  const NetworkFailure({
    super.message = 'Network request failed',
    this.status,
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  }) : super(category: FailureCode.network);

  @override
  List<Object?> get props => [...super.props, status];
}

class TimeoutFailure extends NetworkFailure {
  const TimeoutFailure({
    super.message = 'The request timed out',
    super.status,
    super.cause,
    super.stackTrace,
    super.code,
    super.details,
  });
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
