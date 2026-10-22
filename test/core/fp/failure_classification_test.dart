import 'dart:async';
import 'dart:io';

import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

/// KAN-603: one classification of the same real condition on native and web.
/// The cases follow the condition table of the KAN-599 review (A.1): the
/// ticket's own statements are the source (the review appendix is not in the
/// repository).
class _Case {
  _Case(this.name, this.error, this.code);
  final String name;
  final Object error;
  final FailureCode code;
}

final List<_Case> _cases = <_Case>[
  // Native.
  _Case(
    'native SocketException',
    const SocketException('Failed host lookup'),
    FailureCode.noInternet,
  ),
  // Web: the browser's fetch failure surfaces as the http ClientException.
  _Case(
    'web ClientException (Failed to fetch)',
    ClientException('Failed to fetch', Uri.parse('https://x.supabase.co')),
    FailureCode.noInternet,
  ),
  _Case(
    'TimeoutException',
    TimeoutException('request', const Duration(seconds: 15)),
    FailureCode.timeout,
  ),
  _Case(
    'AuthRetryableFetchException is no-internet, not server',
    AuthRetryableFetchException(message: 'fetch failed'),
    FailureCode.noInternet,
  ),
  _Case(
    'Postgrest 401',
    const PostgrestException(message: 'x', code: '401'),
    FailureCode.unauthenticated,
  ),
  _Case(
    'Postgrest PGRST303 (JWT expired)',
    const PostgrestException(message: 'JWT expired', code: 'PGRST303'),
    FailureCode.unauthenticated,
  ),
  _Case(
    'Postgrest 403',
    const PostgrestException(message: 'x', code: '403'),
    FailureCode.forbidden,
  ),
  _Case(
    'Postgrest 404',
    const PostgrestException(message: 'x', code: '404'),
    FailureCode.notFound,
  ),
  _Case(
    'Postgrest 500',
    const PostgrestException(message: 'x', code: '500'),
    FailureCode.server,
  ),
  _Case(
    'Postgrest unknown code from a responding server',
    const PostgrestException(message: 'x', code: 'XX000'),
    FailureCode.server,
  ),
  _Case(
    'AuthApiException 401',
    AuthApiException('bad', statusCode: '401'),
    FailureCode.unauthenticated,
  ),
  _Case(
    'AuthApiException 503',
    AuthApiException('down', statusCode: '503'),
    FailureCode.server,
  ),
  _Case('an arbitrary error', StateError('boom'), FailureCode.unknown),
];

void main() {
  group('Failure.from and classifyError agree (native and web)', () {
    for (final c in _cases) {
      test(c.name, () {
        expect(classifyError(c.error), c.code);
        expect(Failure.from(c.error).category, c.code);
      });
    }
  });

  group('SupabaseErrorMapper gives the same classes', () {
    const mapper = SupabaseErrorMapper();

    test('SocketException and web ClientException are both no-internet', () {
      final native = mapper.map(const SocketException('x'));
      final web = mapper.map(ClientException('Failed to fetch'));
      expect(native, isA<NetworkFailure>());
      expect(web, isA<NetworkFailure>());
      expect(native.category, FailureCode.noInternet);
      expect(web.category, FailureCode.noInternet);
    });

    test('a timeout is its own class, not merged into network', () {
      final f = mapper.map(TimeoutException('x'));
      expect(f, isA<TimeoutFailure>());
      expect(f.category, FailureCode.timeout);
      expect(f.isNoInternet, isFalse);
    });

    test('AuthRetryableFetchException is no-internet, not server', () {
      final f = mapper.map(AuthRetryableFetchException(message: 'x'));
      expect(f.category, FailureCode.noInternet);
      expect(f.category, isNot(FailureCode.server));
    });

    test('an expired JWT is unauthenticated', () {
      final f = mapper.map(
        const PostgrestException(message: 'JWT expired', code: 'PGRST303'),
      );
      expect(f.category, FailureCode.unauthenticated);
      expect(f.isUnauthorized, isTrue);
    });
  });

  group('no substring matching on status numbers', () {
    test('text containing 401 or 404 is not an auth or not-found failure', () {
      expect(
        Failure.from(Exception('order 4012 shipped')).category,
        FailureCode.unknown,
      );
      expect(
        Failure.from('error 404 in text only').category,
        FailureCode.unknown,
      );
      expect(
        Failure.from(Exception('unauthorized')).category,
        FailureCode.unknown,
      );
    });
  });

  test('legacy getters still answer for old callers', () {
    final f = Failure(category: FailureCode.noInternet);
    expect(f.isNetwork, isTrue);
    expect(const TimeoutFailure().isTimeout, isTrue);
    expect(const TimeoutFailure().isNoInternet, isFalse);
    expect(const UnauthenticatedFailure().isUnauthorized, isTrue);
  });
}
