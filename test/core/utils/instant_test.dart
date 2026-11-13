// KAN-927: timestamps cross the wire as UTC and are held as viewer-local.
//
// The Dubai-specific expectations (18:00 local <-> 14:00Z) run when the test
// process is in a +04:00 zone: `TZ=Asia/Dubai flutter test <this file>`.
// The zone-independent expectations run everywhere (CI is UTC).
import 'package:dabbler/core/utils/instant.dart';
import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;

bool get _inDubaiOffset =>
    DateTime(2026, 11, 20, 18).timeZoneOffset == const Duration(hours: 4);

Map<String, dynamic> _gameRow(String startAt, String endAt) => {
  'id': 'g1',
  'title': 'Padel',
  'start_at': startAt,
  'end_at': endAt,
  'capacity': 4,
  'listing_visibility': 'public',
};

void main() {
  group('write: picked local time -> UTC instant', () {
    test('toWireInstant sends the UTC instant with a Z suffix', () {
      final picked = DateTime(2026, 11, 20, 18); // what the picker builds
      final wire = toWireInstant(picked);
      expect(wire.endsWith('Z'), isTrue);
      expect(DateTime.parse(wire).isAtSameMomentAs(picked), isTrue);
      if (_inDubaiOffset) {
        expect(wire, '2026-11-20T14:00:00.000Z');
      }
    });

    test('a UTC value is sent unchanged; null stays null', () {
      expect(
        toWireInstant(DateTime.utc(2026, 11, 20, 2)),
        '2026-11-20T02:00:00.000Z',
      );
      expect(toWireInstantOrNull(null), isNull);
    });
  });

  group('read: server UTC -> viewer local', () {
    test('parseInstantLocal returns local time for the same instant', () {
      final local = parseInstantLocal('2026-11-20T14:00:00+00:00')!;
      expect(local.isUtc, isFalse);
      expect(local.isAtSameMomentAs(DateTime.utc(2026, 11, 20, 14)), isTrue);
      if (_inDubaiOffset) expect(local.hour, 18);
      expect(parseInstantLocal(null), isNull);
      expect(parseInstantLocal(''), isNull);
      expect(parseInstantLocal('not a date'), isNull);
    });

    test('GameModel holds local start/end and local HH:mm strings', () {
      final g = GameModel.fromJson(
        _gameRow('2026-11-20T14:00:00+00:00', '2026-11-20T15:30:00+00:00'),
      );
      expect(g.scheduledDate.isUtc, isFalse);
      final expected = DateTime.utc(2026, 11, 20, 14).toLocal();
      expect(g.startTime, DateFormat('HH:mm').format(expected));
      if (_inDubaiOffset) {
        expect(g.startTime, '18:00');
        expect(g.endTime, '19:30');
      }
    });

    test('meetup models parse to local and serialise back to UTC', () {
      final m = MeetupListItem.fromJson({
        'id': 'm1',
        'start_at': '2026-11-20T02:00:00+00:00',
      });
      expect(m.startAt.isUtc, isFalse);
      if (_inDubaiOffset) expect(m.startAt.hour, 6);
      expect(m.toJson()['start_at'], '2026-11-20T02:00:00.000Z');
    });

    test(
      'round trip: picked local -> wire -> parsed is the same wall time',
      () {
        final picked = DateTime(2026, 11, 20, 18);
        final back = parseInstantLocal(toWireInstant(picked))!;
        expect(back, picked);
      },
    );
  });

  testWidgets('a card-style label shows the viewer-local time', (tester) async {
    final g = GameModel.fromJson(
      _gameRow('2026-11-20T14:00:00+00:00', '2026-11-20T15:00:00+00:00'),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Text(DateFormat.jm().format(g.scheduledDate)),
      ),
    );
    final expected = DateFormat.jm().format(
      DateTime.utc(2026, 11, 20, 14).toLocal(),
    );
    expect(find.text(expected), findsOneWidget);
    if (_inDubaiOffset) {
      expect(expected.replaceAll('\u202f', ' '), '6:00 PM');
    }
  });
}
