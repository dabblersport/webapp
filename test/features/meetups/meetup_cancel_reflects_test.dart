// KAN-937: a meetup the host cancels shows as cancelled on the open details at
// once — the cancel action refetches the card from the network (not the cached
// copy), with no app reload.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/services/connectivity_service.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'meetup_mocks.mocks.dart';

void main() {
  const String meetupId = '11111111-1111-1111-1111-111111111111';

  Map<String, dynamic> cardRow({bool cancelled = false}) => <String, dynamic>{
    'id': meetupId,
    'event_id': meetupId,
    'title': 'Run',
    'start_at': '2026-11-20T06:00:00Z',
    'end_at': null,
    'sport_key': null,
    'location_name': null,
    'is_cancelled': cancelled,
  };

  test('cancel: the open details flip to cancelled without a reload', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final cache = OfflineCache(prefs: prefs);
    final ds = MockMeetupDataSource();
    final resume = StreamController<void>.broadcast();
    final network = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(resume.close);
    addTearDown(network.close);

    var cancelled = false;
    when(
      ds.card(meetupId, 'player'),
    ).thenAnswer((_) async => cardRow(cancelled: cancelled));
    when(ds.cancel(meetupId)).thenAnswer((_) async => cancelled = true);

    final c = ProviderContainer(
      overrides: [
        meetupDataSourceProvider.overrideWithValue(ds),
        offlineCacheProvider.overrideWithValue(cache),
        cacheAccountIdProvider.overrideWith(
          (ref) => CacheAccountNotifier.fixed('account-a'),
        ),
        meetupResumeSignalProvider.overrideWithValue(resume.stream),
        connectivityProvider.overrideWith(
          (ref) => ConnectivityNotifier(
            changes: network.stream,
            check: () async => <ConnectivityResult>[ConnectivityResult.wifi],
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    // The details screen is open (and its card is now in the device cache).
    c.listen(meetupCardProvider(meetupId), (_, _) {});
    expect(
      (await c.read(meetupCardProvider(meetupId).future)).isCancelled,
      isFalse,
    );

    final r = await c.read(meetupActionsProvider).cancel(meetupId);
    expect(r.isSuccess, isTrue);

    final card = await c.read(meetupCardProvider(meetupId).future);
    expect(card.isCancelled, isTrue);
    verify(ds.cancel(meetupId)).called(1);
  });
}
