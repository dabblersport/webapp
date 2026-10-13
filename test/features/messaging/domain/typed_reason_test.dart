import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessagingReason', () {
    test('wire names are unique snake_case', () {
      final names = MessagingReason.values.map((r) => r.wireName).toList();
      expect(names.toSet().length, names.length);
      for (final n in names) {
        expect(RegExp(r'^[a-z]+(_[a-z]+)*$').hasMatch(n), isTrue, reason: n);
      }
    });

    test('every reason round-trips through its wire name', () {
      for (final r in MessagingReason.values) {
        expect(MessagingReason.fromWire(r.wireName), r);
      }
    });

    test('the proposed reason names are all present', () {
      const proposed = <String>[
        'not_in_pilot',
        'not_a_member',
        'removed',
        'left_read_only',
        'game_ended',
        'game_cancelled',
        'blocked',
        'suspended',
        'rate_limited',
        'not_found',
        'invalid_request',
        'offline',
      ];
      for (final n in proposed) {
        expect(MessagingReason.fromWire(n), isNot(MessagingReason.unknown));
      }
    });

    test('an unrecognised, empty or missing reason maps to unknown', () {
      expect(
        MessagingReason.fromWire('a_reason_from_the_future'),
        MessagingReason.unknown,
      );
      expect(MessagingReason.fromWire(''), MessagingReason.unknown);
      expect(MessagingReason.fromWire(null), MessagingReason.unknown);
      expect(MessagingReason.fromWire('NOT_IN_PILOT'), MessagingReason.unknown);
    });

    test('only offline and unknown are client-side reasons', () {
      final client = MessagingReason.values.where((r) => !r.isServerReason);
      expect(client.toSet(), {
        MessagingReason.offline,
        MessagingReason.unknown,
      });
    });
  });

  group('MessagingFailure.fromErrorBody', () {
    Map<String, dynamic> body(String reason, {String? message, int? retry}) => {
      'error': {
        'reason': reason,
        if (message != null) 'message': message,
        if (retry != null) 'retry_after_seconds': retry,
      },
    };

    test('a mapped typed reason round-trips from the error body', () {
      final expectedStatus = <String, int>{
        'not_in_pilot': 403,
        'not_a_member': 403,
        'removed': 403,
        'left_read_only': 403,
        'game_ended': 409,
        'game_cancelled': 409,
        'blocked': 403,
        'suspended': 403,
        'rate_limited': 429,
        'not_found': 404,
        'invalid_request': 400,
      };
      for (final e in expectedStatus.entries) {
        final f = MessagingFailure.fromErrorBody(e.value, body(e.key));
        expect(f.reason.wireName, e.key);
        expect(f.httpStatus, e.value);
        expect(f.category, f.reason.category);
      }
    });

    test('categories line up with the app-wide failure categories', () {
      FailureCode cat(String r, int s) =>
          MessagingFailure.fromErrorBody(s, body(r)).category;
      expect(cat('not_found', 404), FailureCode.notFound);
      expect(cat('rate_limited', 429), FailureCode.rateLimited);
      expect(cat('invalid_request', 400), FailureCode.validation);
      expect(cat('game_ended', 409), FailureCode.conflict);
      expect(cat('not_a_member', 403), FailureCode.forbidden);
    });

    test('rate_limited carries retry_after_seconds and the message', () {
      final f = MessagingFailure.fromErrorBody(
        429,
        body('rate_limited', message: 'slow down', retry: 12),
      );
      expect(f.reason, MessagingReason.rateLimited);
      expect(f.retryAfterSeconds, 12);
      expect(f.message, 'slow down');
    });

    test('an unrecognised server reason maps to unknown, not a crash', () {
      final f = MessagingFailure.fromErrorBody(
        403,
        body('a_reason_from_the_future'),
      );
      expect(f.reason, MessagingReason.unknown);
      expect(f.httpStatus, 403);
    });

    test('offline is never accepted from the server', () {
      final f = MessagingFailure.fromErrorBody(400, body('offline'));
      expect(f.reason, MessagingReason.unknown);
    });

    test('a 401 and a 5XX carry no reason: unknown with a status category', () {
      final a = MessagingFailure.fromErrorBody(401, {'error': {}});
      expect(a.reason, MessagingReason.unknown);
      expect(a.category, FailureCode.unauthorized);
      final b = MessagingFailure.fromErrorBody(503, null);
      expect(b.reason, MessagingReason.unknown);
      expect(b.category, FailureCode.server);
    });

    test('malformed bodies never throw', () {
      for (final bad in <Object?>[
        null,
        'oops',
        42,
        <Object?>[],
        {'error': 5},
        {
          'error': {'reason': 7},
        },
        {'nope': true},
      ]) {
        final f = MessagingFailure.fromErrorBody(500, bad);
        expect(f.reason, MessagingReason.unknown);
      }
    });

    test('offline() is a network failure with the offline reason', () {
      final f = MessagingFailure.offline();
      expect(f.reason, MessagingReason.offline);
      expect(f.category, FailureCode.network);
    });

    test('it travels inside Result<T, Failure> and keeps its reason', () {
      final Result<int, Failure> r = Err<int, Failure>(
        MessagingFailure.fromErrorBody(409, body('game_ended')),
      );
      final err = r.requireError;
      expect(err, isA<MessagingFailure>());
      expect((err as MessagingFailure).reason, MessagingReason.gameEnded);
    });
  });
}
