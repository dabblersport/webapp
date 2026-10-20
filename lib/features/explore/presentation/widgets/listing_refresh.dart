import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pull-to-refresh plumbing shared by the Games, Venues and Meetups listings
/// (KAN-598). The gesture and loader are the feed's own ([DabblerRefresh]);
/// what the listings add is a refresh that is honest about its data:
///
///  * it waits for the refetched data (success or error), so the loader turns
///    for exactly as long as the query takes and is dismissed on either outcome;
///  * it is single-flight per listing, so a second pull (another tab, a retry
///    while one is running) joins the running refresh instead of racing it.

/// Runs one refresh at a time; a call made while one is running returns that
/// run's future.
class ListingRefresher {
  Future<void>? _inFlight;

  /// Runs [body] unless a refresh is already running, then waits the feed's
  /// settle beat. Errors never escape: the listing shows its own error state
  /// and the loader is dismissed.
  Future<void> run(Future<void> Function() body) => _inFlight ??= _run(body);

  Future<void> _run(Future<void> Function() body) async {
    try {
      await body();
    } catch (_) {
      // The provider already carries the error; the listing renders it.
    } finally {
      _inFlight = null;
    }
    // The same settle beat the feed ends its refresh with.
    await Future<void>.delayed(DabblerMotion.delaySettle);
  }
}

/// One refresher per listing ('games', 'venues', 'meetups'), scoped to the
/// ProviderScope so nothing leaks between sessions or tests.
final listingRefresherProvider = Provider.family<ListingRefresher, String>(
  (ref, listing) => ListingRefresher(),
);

/// Awaits [future] and swallows its outcome: a failed refetch is shown by the
/// listing's error state, not thrown into the pull gesture.
Future<void> settle(Future<Object?> future) async {
  try {
    await future;
  } catch (_) {}
}
