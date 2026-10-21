import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/sync/pending_settings_store.dart';

/// The signed-in account id the cache is keyed by (KAN-605). Follows the auth
/// session, so an account switch rebuilds everything that watches it. Null
/// when signed out (nothing is cached or read then).
class CacheAccountNotifier extends StateNotifier<String?> {
  CacheAccountNotifier() : super(_current()) {
    try {
      _sub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        final next = event.session?.user.id;
        // A sign-out from any path (expiry, another screen) wipes the cache.
        if (event.event == AuthChangeEvent.signedOut) {
          unawaited(OfflineCache.wipeAll());
          unawaited(const PendingSettingsStore().wipe());
        }
        if (next != state) state = next;
      });
    } catch (_) {
      // No Supabase (a unit test): the id stays whatever it was.
    }
  }

  /// A fixed account, with no auth listener (tests).
  CacheAccountNotifier.fixed(super.accountId);

  StreamSubscription<AuthState>? _sub;

  static String? _current() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final cacheAccountIdProvider =
    StateNotifierProvider<CacheAccountNotifier, String?>(
      (ref) => CacheAccountNotifier(),
    );

/// The cache. Reading it for an account also removes every other account's
/// entries (the account-switch wipe).
final offlineCacheProvider = Provider<OfflineCache>((ref) {
  final account = ref.watch(cacheAccountIdProvider);
  final cache = OfflineCache.instance;
  if (account != null) unawaited(cache.wipe(keepAccountId: account));
  return cache;
});

/// Per provider instance: it has built before / it re-ran because its own
/// background refresh finished (not because of an explicit invalidation).
final Expando<bool> _built = Expando<bool>('swr.built');
final Expando<bool> _selfInvalidated = Expando<bool>('swr.self');

/// Stale-while-revalidate for a list or detail that loads once (KAN-605).
///
/// First build: with a cached copy it returns that at once and refreshes in
/// the background (the provider then re-runs and picks up the fresh copy); a
/// background failure is silent and keeps the cached copy. Without a cache it
/// fetches, bounded by [kRequestTimeout], and a failure is the caller's error
/// as before.
///
/// An explicit invalidation (pull-to-refresh, a join or RSVP just done) goes
/// to the network first so the screen shows the new truth, and falls back to
/// the cached copy only when the network fails. Signed out, it just fetches.
Future<T> swrFetch<T>(
  Ref ref, {
  required String key,
  required Future<T> Function() fetch,
  required Object? Function(T value) encode,
  required T Function(Object? json) decode,
}) async {
  final account = ref.read(cacheAccountIdProvider);
  if (account == null) return fetch();
  final cache = ref.read(offlineCacheProvider);

  final rebuilt = _built[ref] == true;
  final selfTriggered = _selfInvalidated[ref] == true;
  _built[ref] = true;
  _selfInvalidated[ref] = false;

  var disposed = false;
  ref.onDispose(() => disposed = true);

  Future<T> network() async {
    final started = DateTime.now();
    final value = await fetch().timeout(kRequestTimeout);
    try {
      await cache.write(account, key, encode(value), requestStartedAt: started);
    } catch (_) {
      // An unencodable value is simply not cached.
    }
    return value;
  }

  T? cached;
  final hit = await cache.read(account, key);
  if (hit != null) {
    try {
      cached = decode(hit.payload);
    } catch (_) {
      cached = null; // a shape that no longer parses: treat as no cache
    }
  }

  if (rebuilt && !selfTriggered) {
    // Explicit invalidation: the network answers, the cache only covers a
    // failure.
    try {
      return await network();
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  if (cached == null) return network();

  if (!selfTriggered) {
    unawaited(
      network().then<void>(
        (_) {
          if (disposed) return;
          _selfInvalidated[ref] = true;
          ref.invalidateSelf();
        },
        onError: (Object _) {
          // Silent: the cached copy stays on screen.
        },
      ),
    );
  }
  return cached;
}
