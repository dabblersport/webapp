import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'supabase_client.dart';
import 'supabase_error_mapper.dart';

/// Thin wrapper around [SupabaseClient] to centralize access helpers.
class SupabaseService {
  SupabaseService(this._client, this._errorMapper);

  final SupabaseClient _client;
  final SupabaseErrorMapper _errorMapper;

  SupabaseClient get client => _client;

  /// Returns the authenticated user's id if available.
  String? authUserId() {
    // On some platforms (notably Android during cold-start / resume),
    // `currentUser` may briefly be null while the persisted session is
    // still available. Prefer session.user.id when present.
    return _client.auth.currentSession?.user.id ?? _client.auth.currentUser?.id;
  }

  /// Maps Supabase/PostgREST errors into domain specific failures.
  Failure mapPostgrest(
    PostgrestException exception, {
    String? overrideMessage,
    StackTrace? stackTrace,
  }) {
    final mapped = _errorMapper.map(
      exception,
      overrideMessage: overrideMessage,
      stackTrace: stackTrace,
    );

    final message = mapped.message;
    final code = exception.code;

    // Check for specific error codes
    if (code == 'PGRST301' || code == '42501') {
      return UnauthenticatedFailure(
        message: message,
        cause: mapped.cause,
        stackTrace: mapped.stackTrace,
      );
    }

    if (code == 'PGRST116') {
      return NotFoundFailure(
        message: message,
        cause: mapped.cause,
        stackTrace: mapped.stackTrace,
      );
    }

    // Check for validation errors
    if (code == '23505' ||
        code == '23514' ||
        code == '23502' ||
        code == 'PGRST204') {
      return ValidationFailure(
        message: message,
        fieldErrors: _extractFieldErrors(exception),
        cause: mapped.cause,
        stackTrace: mapped.stackTrace,
      );
    }

    return mapped;
  }

  /// Maps Supabase/PostgREST errors from arbitrary throwables.
  Failure mapPostgrestError(
    Object error, {
    String? overrideMessage,
    StackTrace? stackTrace,
  }) {
    if (error is PostgrestException) {
      return mapPostgrest(
        error,
        overrideMessage: overrideMessage,
        stackTrace: stackTrace,
      );
    }
    return _errorMapper.map(
      error,
      overrideMessage: overrideMessage,
      stackTrace: stackTrace,
    );
  }

  /// Returns a query builder for the provided [table].
  SupabaseQueryBuilder from(String table) {
    return _client.from(table);
  }

  /// Calls a Postgres function and returns the query builder for further chaining.
  PostgrestFilterBuilder<dynamic> rpc(
    String fn, {
    Map<String, dynamic>? params,
  }) {
    return _client.rpc(fn, params: params ?? const <String, dynamic>{});
  }

  /// Executes the provided query and attempts to return a single row.
  Future<PostgrestMap?> maybeSingle(
    PostgrestFilterBuilder<Map<String, dynamic>> query,
  ) async {
    final result = await query.maybeSingle();
    if (result == null) {
      return null;
    }
    return Map<String, dynamic>.from(result);
  }

  /// Executes the provided query and returns all rows as a typed list.
  Future<List<PostgrestMap>> getList(
    PostgrestFilterBuilder<Map<String, dynamic>> query,
  ) async {
    final response = await query;
    final data = List<dynamic>.from(response as List);
    return data
        .map(
          (dynamic item) =>
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
        )
        .toList();
  }

  /// Fallback mapper for unexpected errors.
  Failure mapGeneric(
    Object error,
    StackTrace stackTrace, {
    String? overrideMessage,
  }) {
    return _errorMapper.map(
      error,
      overrideMessage: overrideMessage,
      stackTrace: stackTrace,
    );
  }

  Map<String, List<String>>? _extractFieldErrors(PostgrestException exception) {
    try {
      final details = exception.details;
      if (details is Map && details['errors'] is Map) {
        final rawErrors = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(details['errors'] as Map),
        );
        return rawErrors.map(
          (key, value) => MapEntry(
            key,
            value is Iterable
                ? value.map((entry) => entry.toString()).toList()
                : [value.toString()],
          ),
        );
      }
    } catch (_) {
      // Ignore parsing issues and fall back to generic validation failure
    }
    return null;
  }
}

/// Provides an instance of [SupabaseService] backed by the global client.
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final errorMapper = ref.watch(supabaseErrorMapperProvider);
  return SupabaseService(client, errorMapper);
});
