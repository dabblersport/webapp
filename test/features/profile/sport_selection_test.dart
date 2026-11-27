// KAN-1057 QA: removing a sport unticks it at once and a stale provider
// value cannot re-tick it; a failed removal is restored; taps while a write
// is in flight are ignored.

import 'package:dabbler/features/profile/domain/services/sport_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remove unticks immediately and stays unticked on a stale value', () {
    final sel = SportSelection(['fb'])..mergeFromProvider(['fb', 'gym']);
    expect(sel.isTicked('gym'), isTrue);
    expect(sel.startRemove('gym'), isTrue);
    expect(sel.isTicked('gym'), isFalse);
    sel.mergeFromProvider(['fb', 'gym']); // stale, before the refetch
    expect(sel.isTicked('gym'), isFalse);
    sel.finish('gym', removing: true, ok: true);
    sel.mergeFromProvider(['fb', 'gym']);
    expect(sel.isTicked('gym'), isFalse);
  });

  test('taps on a chip with a write in flight are ignored', () {
    final sel = SportSelection(['fb', 'gym']);
    expect(sel.startRemove('gym'), isTrue);
    expect(sel.startRemove('gym'), isFalse);
    expect(sel.startAdd('gym'), isFalse);
    expect(sel.isPending('gym'), isTrue);
  });

  test('a failed remove restores the chip', () {
    final sel = SportSelection(['fb', 'gym']);
    sel.startRemove('gym');
    sel.finish('gym', removing: true, ok: false);
    expect(sel.isTicked('gym'), isTrue);
    expect(sel.isPending('gym'), isFalse);
  });

  test('re-adding a removed sport ticks it again', () {
    final sel = SportSelection(['fb', 'gym']);
    sel.startRemove('gym');
    sel.finish('gym', removing: true, ok: true);
    expect(sel.startAdd('gym'), isTrue);
    sel.finish('gym', removing: false, ok: true);
    expect(sel.isTicked('gym'), isTrue);
    sel.mergeFromProvider(['gym']);
    expect(sel.isTicked('gym'), isTrue);
  });
}
