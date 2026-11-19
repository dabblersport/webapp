import 'package:dabbler/services/live_activity/live_activity_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = <String, Object?>{
    'state': 'started',
    'state_version': 4,
    'event_id': 'e1',
  };

  test('KAN-1024: checkin_open and checkin_closes_at parse', () {
    final c = LiveActivityContent.tryParse({
      ...base,
      'checkin_open': true,
      'checkin_closes_at': 1700000000,
    })!;
    expect(c.checkinOpen, isTrue);
    expect(c.checkinClosesAt!.millisecondsSinceEpoch, 1700000000 * 1000);
  });

  test('KAN-1024: older payload leaves both null', () {
    final c = LiveActivityContent.tryParse(base)!;
    expect(c.checkinOpen, isNull);
    expect(c.checkinClosesAt, isNull);
  });
}
