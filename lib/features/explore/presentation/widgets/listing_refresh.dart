import 'dart:async';

import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
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

/// KAN-606: whether a listing's query still holds rows from an earlier load.
/// A failed refetch keeps them on screen (`when(skipError: ...)`); the error
/// answer is only for a list that has nothing to show.
bool keepsRows(AsyncValue<List<Object?>> value) =>
    value.hasValue && value.requireValue.isNotEmpty;

/// KAN-606: whether [value] is a failed refetch that kept its rows.
bool refreshFailedWithRows(AsyncValue<List<Object?>> value) =>
    value.hasError && keepsRows(value);

/// The transient "Couldn't refresh. Showing saved content." toast after a
/// failed refetch that kept the list. Does nothing when [context] is gone or
/// no toast host is mounted.
void showListingRefreshFailedToast(BuildContext context) {
  if (!context.mounted) return;
  DabblerToastProvider.maybeOf(context)?.show(
    DabblerToastSpec(
      message: AppLocalizations.of(context).offline_refresh_failed,
      tone: DabblerToastTone.warning,
    ),
  );
}

/// KAN-755: converges a listing (and an open detail) after an event's title,
/// time, location or cancel state changes, from any supported signal (a
/// Realtime change, a reconnect, a return from the editor).
///
///  * the signal carries NO payload: the listing re-runs its own RLS-bound
///    query, so nothing a subscriber is not allowed to see is ever rendered
///    from a change message;
///  * bursts coalesce: any number of signals inside [window] cost one refetch,
///    and signals arriving while that refetch runs cost exactly one follow-up,
///    so there are no duplicate requests;
///  * a reconnect is just another signal, so the listing converges on whatever
///    changed while the socket was down;
///  * [dispose] (session end, account switch) cancels the pending timer and
///    drops late signals, so an old account's listing never refetches or updates.
class ListingChangeSignal {
  ListingChangeSignal(
    this._refresh, {
    this.window = const Duration(milliseconds: 300),
  });

  final Future<void> Function() _refresh;
  final Duration window;

  Timer? _timer;
  bool _running = false;
  bool _dirty = false;
  bool _disposed = false;

  /// An event the listing shows changed (any field, or cancel).
  void changed() {
    if (_disposed) return;
    if (_running) {
      _dirty = true;
      return;
    }
    _timer ??= Timer(window, _fire);
  }

  /// The realtime channel came back: refetch once to pick up missed changes.
  void reconnected() => changed();

  Future<void> _fire() async {
    _timer = null;
    if (_disposed) return;
    _running = true;
    try {
      await _refresh();
    } catch (_) {
      // The query's own error state is shown by the listing.
    } finally {
      _running = false;
    }
    if (_dirty && !_disposed) {
      _dirty = false;
      _timer ??= Timer(window, _fire);
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}

/// One signal per listing, tied to the ProviderScope (a signed-out or switched
/// session disposes the scope's providers, which disposes the signal).
final listingChangeSignalProvider =
    Provider.family<ListingChangeSignal, ListingChangeSignalArgs>((ref, args) {
      final signal = ListingChangeSignal(args.refresh, window: args.window);
      ref.onDispose(signal.dispose);
      return signal;
    });

/// Family key: the listing name plus the refetch to run. Equal by [listing]
/// only, so re-reading the provider never builds a second signal.
class ListingChangeSignalArgs {
  const ListingChangeSignalArgs(
    this.listing,
    this.refresh, {
    this.window = const Duration(milliseconds: 300),
  });

  final String listing;
  final Future<void> Function() refresh;
  final Duration window;

  @override
  bool operator ==(Object other) =>
      other is ListingChangeSignalArgs && other.listing == listing;

  @override
  int get hashCode => listing.hashCode;
}
