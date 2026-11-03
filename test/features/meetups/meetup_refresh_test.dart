// KAN-753 (KAN-716 V04): the meetup reads on screen refetch when the app
// resumes or the connection returns. A burst of signals is one refresh, a
// refresh never runs while offline, and nothing scheduled or fetched for an
// old account reaches the new one. The path only reads: no write is issued.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/services/connectivity_service.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'meetup_mocks.mocks.dart';

/// A fixed account the test can switch, as a sign-in to another account does.
class _Account extends CacheAccountNotifier {
  _Account(super.accountId) : super.fixed();
  void switchTo(String id) => state = id;
}

void main() {
  const String meetupId = '11111111-1111-1111-1111-111111111111';
  const String eventId = '99999999-9999-9999-9999-999999999999';
  const Duration debounce = Duration(milliseconds: 20);
  const Duration settle = Duration(milliseconds: 80);

  late MockMeetupDataSource ds;
  late OfflineCache cache;
  late StreamController<void> resume;
  late StreamController<List<ConnectivityResult>> network;
  late _Account account;

  // An old row: null title / end / sport. It must parse as it is.
  Map<String, dynamic> listRow({String? title}) => <String, dynamic>{
    'id': meetupId,
    'event_id': eventId,
    'title': title,
    'start_at': '2026-11-10T06:00:00Z',
    'end_at': null,
    'sport_id': null,
  };

  Map<String, dynamic> cardRow({
    String? title,
    String start = '2026-11-10T06:00:00Z',
    String? location,
    bool cancelled = false,
  }) => <String, dynamic>{
    'id': meetupId,
    'event_id': eventId,
    'title': title,
    'start_at': start,
    'end_at': null,
    'sport_key': null,
    'location_name': location,
    'is_cancelled': cancelled,
  };

  void serve({required Map<String, dynamic> list, Map<String, dynamic>? card}) {
    when(
      ds.fetchMeetupList(sportId: null, limit: 20, offset: 0),
    ).thenAnswer((_) async => <Map<String, dynamic>>[list]);
    when(
      ds.card(meetupId, 'player'),
    ).thenAnswer((_) async => card ?? cardRow());
  }

  int listCalls() =>
      verify(ds.fetchMeetupList(sportId: null, limit: 20, offset: 0)).callCount;
  int cardCalls() => verify(ds.card(meetupId, 'player')).callCount;

  void verifyNoWrites() {
    verifyNever(ds.create(any, actorType: anyNamed('actorType')));
    verifyNever(ds.rsvp(any, any, profileId: anyNamed('profileId')));
    verifyNever(ds.cancel(any));
    verifyNever(ds.update(any));
    verifyNever(ds.decideRequest(any, any, any));
    verifyNever(ds.removeAttendee(any, any));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    cache = OfflineCache(prefs: prefs);
    ds = MockMeetupDataSource();
    resume = StreamController<void>.broadcast();
    network = StreamController<List<ConnectivityResult>>.broadcast();
    account = _Account('account-a');
  });

  tearDown(() async {
    await resume.close();
    await network.close();
  });

  ProviderContainer open({Duration window = debounce}) {
    final c = ProviderContainer(
      overrides: [
        meetupDataSourceProvider.overrideWithValue(ds),
        offlineCacheProvider.overrideWithValue(cache),
        cacheAccountIdProvider.overrideWith((ref) => account),
        meetupResumeSignalProvider.overrideWithValue(resume.stream),
        meetupRefreshDebounceProvider.overrideWithValue(window),
        connectivityProvider.overrideWith(
          (ref) => ConnectivityNotifier(
            changes: network.stream,
            check: () async => <ConnectivityResult>[ConnectivityResult.wifi],
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Keeps the list and the details open, as two screens on the stack do.
  Future<void> openScreens(ProviderContainer c) async {
    c.listen(meetupListProvider(null), (_, _) {});
    c.listen(meetupCardProvider(meetupId), (_, _) {});
    await c.read(meetupListProvider(null).future);
    await c.read(meetupCardProvider(meetupId).future);
  }

  test(
    'a null title/end/sport record parses; ids keep their meaning',
    () async {
      serve(list: listRow());
      final c = open();
      await openScreens(c);

      final MeetupListItem item = c
          .read(meetupListProvider(null))
          .requireValue
          .single;
      expect(item.id, meetupId);
      expect(item.eventId, eventId);
      expect(item.title, isNull);
      expect(item.endAt, isNull);
      expect(item.sportId, isNull);

      final MeetupCard card = c.read(meetupCardProvider(meetupId)).requireValue;
      expect(card.id, meetupId);
      expect(card.eventId, eventId);
      expect(card.title, isNull);
      expect(card.sportKey, isNull);
      verifyNoWrites();
    },
  );

  test('resume: a title/time/location/cancel change reaches the open list '
      'and details', () async {
    serve(
      list: listRow(title: 'Run'),
      card: cardRow(title: 'Run'),
    );
    final c = open();
    await openScreens(c);

    serve(
      list: listRow(title: 'Evening run'),
      card: cardRow(
        title: 'Evening run',
        start: '2026-11-10T18:00:00Z',
        location: 'Corniche',
        cancelled: true,
      ),
    );
    resume.add(null);
    await Future<void>.delayed(settle);

    expect(
      c.read(meetupListProvider(null)).requireValue.single.title,
      'Evening run',
    );
    final MeetupCard card = c.read(meetupCardProvider(meetupId)).requireValue;
    expect(card.title, 'Evening run');
    expect(card.startAt, DateTime.utc(2026, 11, 10, 18));
    expect(card.locationName, 'Corniche');
    expect(card.isCancelled, isTrue);
    expect(card.id, meetupId);
    verifyNoWrites();
  });

  test('a burst of resume and reconnect signals is one request per open '
      'read', () async {
    serve(list: listRow());
    // Signals arrive apart, as a real resume and reconnect do, so each one
    // would rebuild the reads on its own without the debounce.
    const Duration window = Duration(milliseconds: 300);
    const Duration gap = Duration(milliseconds: 15);
    final c = open(window: window);
    await openScreens(c);
    clearInteractions(ds);

    resume.add(null);
    await Future<void>.delayed(gap);
    resume.add(null);
    await Future<void>.delayed(gap);
    network.add(<ConnectivityResult>[ConnectivityResult.none]);
    await Future<void>.delayed(gap);
    network.add(<ConnectivityResult>[ConnectivityResult.wifi]); // reconnect
    await Future<void>.delayed(gap);
    resume.add(null);
    await Future<void>.delayed(window * 2);

    expect(listCalls(), 1);
    expect(cardCalls(), 1);
    // A read nobody has open is not fetched.
    verifyNever(ds.nearby(any, any, any));
    verifyNoWrites();
  });

  test('offline: no request; the reconnect refreshes and converges', () async {
    serve(list: listRow(title: 'Run'));
    final c = open();
    await openScreens(c);

    network.add(<ConnectivityResult>[ConnectivityResult.none]);
    await pumpEventQueue();
    expect(c.read(connectivityProvider), ConnectionStatus.offline);
    clearInteractions(ds);

    resume.add(null);
    await Future<void>.delayed(settle);
    verifyNever(ds.fetchMeetupList(sportId: null, limit: 20, offset: 0));

    serve(list: listRow(title: 'Moved run'));
    network.add(<ConnectivityResult>[ConnectivityResult.wifi]);
    await Future<void>.delayed(settle);

    expect(listCalls(), 1);
    expect(
      c.read(meetupListProvider(null)).requireValue.single.title,
      'Moved run',
    );
  });

  test('an account switch drops the old account refresh and its in-flight '
      'answer', () async {
    serve(list: listRow(title: 'A meetup'));
    final c = open();
    c.listen(meetupListProvider(null), (_, _) {});
    await c.read(meetupListProvider(null).future);
    final MeetupRefresher old = c.read(meetupRefreshProvider);
    expect(old.accountId, 'account-a');

    // A's refresh is scheduled and its request hangs.
    final Completer<List<Map<String, dynamic>>> stale = Completer();
    when(
      ds.fetchMeetupList(sportId: null, limit: 20, offset: 0),
    ).thenAnswer((_) => stale.future);
    resume.add(null);
    await Future<void>.delayed(settle);

    // Switch to B before A's answer lands.
    serve(list: listRow(title: 'B meetup'));
    account.switchTo('account-b');
    await c.read(meetupListProvider(null).future);
    expect(c.read(meetupRefreshProvider).accountId, 'account-b');
    expect(c.read(meetupRefreshProvider), isNot(same(old)));

    stale.complete(<Map<String, dynamic>>[listRow(title: 'A private')]);
    await Future<void>.delayed(settle);
    expect(
      c.read(meetupListProvider(null)).requireValue.single.title,
      'B meetup',
    );

    // A refresh scheduled for A and fired after the switch does nothing.
    clearInteractions(ds);
    old.schedule();
    await Future<void>.delayed(settle);
    verifyNever(ds.fetchMeetupList(sportId: null, limit: 20, offset: 0));
    verifyNoWrites();
  });
}
