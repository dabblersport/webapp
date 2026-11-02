// KAN-755: the Realtime feed behind the listings' change signal. The source is
// faked: no socket, no network.
import 'package:dabbler/features/explore/presentation/widgets/listing_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> opened;
  late int closed;
  late void Function() fireChange;
  late void Function() fireReconnect;
  late int refetches;
  late ProviderContainer container;

  setUp(() {
    opened = <String>[];
    closed = 0;
    refetches = 0;
    container = ProviderContainer(
      overrides: [
        listingRealtimeSourceProvider.overrideWithValue((
          table,
          onChange,
          onReconnect,
        ) {
          opened.add(table);
          fireChange = onChange;
          fireReconnect = onReconnect;
          return () => closed++;
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  ListingChangeSignalArgs args(String listing) => ListingChangeSignalArgs(
    listing,
    () async => refetches++,
    window: const Duration(milliseconds: 10),
  );

  Future<void> wait() => Future<void>.delayed(const Duration(milliseconds: 60));

  test('a burst of changes costs one refetch of the listing', () async {
    final sub = container.listen(
      listingChangeFeedProvider(args('meetups')),
      (_, _) {},
    );
    expect(opened, ['meetups']);
    fireChange();
    fireChange();
    fireChange();
    await wait();
    expect(refetches, 1);
    sub.close();
  });

  test('the games listing listens to the games table', () {
    container.listen(listingChangeFeedProvider(args('games')), (_, _) {});
    expect(opened, ['games']);
  });

  test('a reconnect refetches once', () async {
    container.listen(listingChangeFeedProvider(args('games')), (_, _) {});
    fireReconnect();
    await wait();
    expect(refetches, 1);
  });

  test(
    'leaving the screen closes the channel and drops late signals',
    () async {
      final sub = container.listen(
        listingChangeFeedProvider(args('games')),
        (_, _) {},
      );
      fireChange();
      sub.close();
      await container.pump();
      await wait();
      expect(closed, 1);
      expect(refetches, 0);
    },
  );
}
