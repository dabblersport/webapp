// KAN-1008 (W3-F1): the ongoing card controller: the closed-card expiry read,
// the retry after a failed read, the notice debounce and signal, and the
// one-shot boundary, resume and notice re-reads.

import 'package:dabbler/features/ongoing/presentation/ongoing_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ongoing_fakes.dart';

void main() {
  setUp(() => ocClock = DateTime(2026, 11, 18, 20, 5));
  testWidgets('a closed card is read again 2h after it was first seen', (
    t,
  ) async {
    ocClock = DateTime(2026, 11, 18, 22);
    final (repo, _) = await ocPump(t, [ocRow(state: 'confirmed')]);
    expect(repo.reads, 1);
    repo.rows = [];
    ocClock = ocClock.add(const Duration(hours: 2, seconds: 2));
    await t.pump(const Duration(hours: 2, seconds: 2));
    await t.pump();
    expect(repo.reads, 2);
    expect(ocKey('ongoing-card-e1'), findsNothing);
    await t.pump(const Duration(hours: 3));
    expect(repo.reads, 2);
  });

  testWidgets('a failed read is retried once, after 1 min', (t) async {
    final (repo, _) = await ocPump(t, [ocRow()], fail: true);
    expect(repo.reads, 1);
    await t.pump(const Duration(seconds: 59));
    expect(repo.reads, 1);
    await t.pump(const Duration(seconds: 2));
    await t.pump();
    expect(repo.reads, 2);
    // Still failing: no further retry, no boundary from stale data.
    await t.pump(const Duration(hours: 1));
    expect(repo.reads, 2);
    // A good read afterwards shows the card.
    repo.fail = false;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump();
    expect(ocKey('ongoing-card-e1'), findsOneWidget);
  });

  testWidgets('a burst of notices makes one read (300 ms debounce)', (t) async {
    final (repo, container) = await ocPump(t, [ocRow()]);
    for (final id in ['n1', 'n2', 'n3']) {
      container.read(ocSignal.notifier).state = id;
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(repo.reads, 1);
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    expect(repo.reads, 2);
  });

  testWidgets('the real notice signal: activity.* reads, others do not', (
    t,
  ) async {
    final inbox = OcInbox();
    final (repo, _) = await ocPump(t, [ocRow()], inbox: inbox);
    expect(repo.reads, 1);
    inbox.add('x1', 'game.player_joined');
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(repo.reads, 1);
    inbox.add('a1', 'activity.checkin_open');
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(repo.reads, 2);
  });

  testWidgets('re-read at the next boundary (one-shot timer)', (t) async {
    final (repo, _) = await ocPump(t, [ocRow()]);
    expect(repo.reads, 1);
    repo.rows = [ocRow(checkIn: 'open')];
    // The next boundary is the start, 25 minutes away (plus the slack).
    ocClock = ocStart.add(const Duration(seconds: 2));
    await t.pump(const Duration(minutes: 25, seconds: 2));
    await t.pump();
    expect(repo.reads, 2);
    expect(ocKey('ongoing-check-in'), findsOneWidget);
    // No polling: nothing more until the next boundary.
    await t.pump(const Duration(minutes: 5));
    expect(repo.reads, 2);
  });

  testWidgets('re-read on resume', (t) async {
    final (repo, _) = await ocPump(t, [ocRow()]);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(repo.reads, 2);
  });

  testWidgets('re-read when an activity notice arrives', (t) async {
    final (repo, container) = await ocPump(t, [ocRow()]);
    repo.rows = [ocRow(cancelled: true)];
    container.read(ocSignal.notifier).state = 'n1';
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    expect(repo.reads, 2);
    expect(
      ocHas(lookupAppLocalizations(const Locale('en')).lc_cancelled),
      findsOneWidget,
    );
  });

  test('notice kinds that trigger a read', () {
    expect(ongoingNoticeKind('activity.checkin_open'), isTrue);
    expect(ongoingNoticeKind('game.cancelled'), isTrue);
    expect(ongoingNoticeKind('game.player_joined'), isFalse);
  });
}
