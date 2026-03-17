import 'dart:async';
import 'dart:io';

import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';

final supabaseErrorMapperProvider = Provider<SupabaseErrorMapper>((ref) {
  return const SupabaseErrorMapper();
});

class SupabaseErrorMapper {
  const SupabaseErrorMapper();

  Failure map(Object error, {String? overrideMessage, StackTrace? stackTrace}) {
    if (error is PostgrestException) {
      return _mapPostgrest(
        error,
        overrideMessage: overrideMessage,
        stackTrace: stackTrace,
      );
    }
    if (error is AuthException) {
      return _mapAuth(
        error,
        overrideMessage: overrideMessage,
        stackTrace: stackTrace,
      );
    }
    if (error is StorageException) {
      return SupabaseFailure(
        message: overrideMessage ?? error.message,
        code: error.statusCode?.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is TimeoutException || error is SocketException) {
      return NetworkFailure(
        message: overrideMessage ?? 'Network connection failed',
        stackTrace: stackTrace,
      );
    }

    return UnexpectedFailure(
      message: overrideMessage ?? error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  Failure _mapAuth(
    AuthException exception, {
    String? overrideMessage,
    StackTrace? stackTrace,
  }) {
    final message = overrideMessage ?? exception.message;
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('invalid login credentials')) {
      return AuthFailure(message: message);
    }
    if (lowerMessage.contains('email') && lowerMessage.contains('exists')) {
      return ConflictFailure(message: message);
    }
    if (lowerMessage.contains('password')) {
      return ValidationFailure(message: message);
    }
    if (lowerMessage.contains('verify') ||
        lowerMessage.contains('confirmation')) {
      return AuthFailure(message: message);
    }

    return SupabaseAuthFailure(
      message: message,
      code: exception.code,
      cause: exception,
      stackTrace: stackTrace,
    );
  }

  Failure _mapPostgrest(
    PostgrestException exception, {
    String? overrideMessage,
    StackTrace? stackTrace,
  }) {
    final message = overrideMessage ?? exception.message;
    final code = exception.code;
    final details = _detailsToMap(exception.details);

    final lowerMessage = message.toLowerCase();
    final lowerDetails = (exception.details ?? '').toString().toLowerCase();

    if (lowerMessage.contains('posts_body_has_non_hashtag_word')) {
      return SupabaseValidationFailure(
        message:
            'Body cannot be only hashtags. Add at least one regular word, or allow hashtag-only posts in DB.',
        details: details,
        code: code,
        cause: exception,
        stackTrace: stackTrace,
      );
    }

    if (code == '42703' &&
        lowerMessage.contains('updated_at') &&
        lowerMessage.contains('hashtags')) {
      return SupabaseValidationFailure(
        message:
            'Database schema mismatch: hashtags.updated_at is missing. Apply the hashtags schema migration, then retry.',
        details: details,
        code: code,
        cause: exception,
        stackTrace: stackTrace,
      );
    }

    // Expired/invalid JWT should be treated as an auth/session problem.
    // PostgREST commonly uses PGRST303 with "Unauthorized" details.
    if (lowerMessage.contains('jwt expired') ||
        lowerMessage.contains('invalid jwt') ||
        code == 'PGRST303' ||
        lowerDetails.contains('unauthorized')) {
      return UnauthenticatedFailure(
        message: 'Session expired. Please sign in again.',
        code: code,
        details: details,
        cause: exception,
        stackTrace: stackTrace,
      );
    }

    // Check code for authorization errors
    if (code == 'PGRST301' || code == '42501') {
      return SupabaseAuthorizationFailure(
        message: message,
        code: code,
        details: details,
        cause: exception,
        stackTrace: stackTrace,
      );
    }

    // Check for not found errors
    if (code == 'PGRST116') {
      return SupabaseNotFoundFailure(
        message: message,
        code: code,
        details: details,
        cause: exception,
        stackTrace: stackTrace,
      );
    }

    // Check for conflict errors (duplicate keys, etc.)
    if (code == '23505') {
      return SupabaseConflictFailure(
        message: message,
        code: code,
        details: details,
        cause: exception,
        stackTrace: stackTrace,
      );
    }

    // Check for validation/bad request errors
    if (code == 'PGRST301' || code == '23514' || code == '23502') {
      return SupabaseValidationFailure(
        message: message,
        details: details,
        code: code,
        cause: exception,
        stackTrace: stackTrace,
      );
    }

    // Default to generic server failure for unknown errors
    return SupabaseFailure(
      message: message,
      code: code,
      details: details,
      cause: exception,
      stackTrace: stackTrace,
    );
  }

  Map<String, dynamic>? _detailsToMap(dynamic details) {
    if (details == null) {
      return null;
    }
    if (details is Map<String, dynamic>) {
      return details;
    }
    if (details is Map) {
      return Map<String, dynamic>.from(details.cast<Object?, Object?>());
    }
    return {'details': details};
  }
}
