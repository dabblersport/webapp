import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dabbler/core/cache/cache_policy.dart';
import 'package:dabbler/core/cache/offline_cache.dart';

/// Runs the scheduled cache cleanup (KAN-613): at app start and on resume,
/// when [interval] has passed since the last run.
///
/// A run removes the signed-in account's entries older than [interval] and
/// holds the size cap ([OfflineCache.cleanup]). An old entry that is on screen
/// is refreshed instead of removed, and only while online; offline it stays.
/// Pending settings edits (KAN-608) live in their own store and are never
/// touched here.
class CacheCleanupScheduler with WidgetsBindingObserver {
  CacheCleanupScheduler({
    required this.cache,
    required this.accountId,
    required this.isOffline,
    this.interval = kCacheCleanupInterval,
    DateTime Function()? now,
    SharedPreferences? prefs,
    ShownCacheEntries? shown,
    bool observeLifecycle = true,
  }) : _now = now ?? DateTime.now,
       _prefs = prefs,
       _shown = shown ?? ShownCacheEntries.instance {
    if (observeLifecycle) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      } catch (_) {
        // No binding (a plain unit test): start and resume are called by hand.
      }
    }
    unawaited(runIfDue());
  }

  static const String lastRunKey = 'offline_cache_cleanup.lastRunAt';

  final OfflineCache cache;
  final String? accountId;

  /// Read only when an entry on screen is due a refresh.
  final bool Function() isOffline;
  final Duration interval;
  final DateTime Function() _now;
  final ShownCacheEntries _shown;
  SharedPreferences? _prefs;
  bool _observing = false;
  bool _running = false;

  Future<SharedPreferences> _p() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Whether a run is due now. A clock set back counts as due.
  Future<bool> isDue() async {
    try {
      final raw = (await _p()).getInt(lastRunKey);
      if (raw == null) return true;
      final last = DateTime.fromMillisecondsSinceEpoch(raw);
      final now = _now();
      return now.isBefore(last) || now.difference(last) >= interval;
    } catch (_) {
      return true;
    }
  }

  /// Runs a cleanup when one is due. Never throws.
  Future<CacheCleanupResult?> runIfDue() async {
    final account = accountId;
    if (account == null || _running) return null;
    _running = true;
    try {
      if (!await isDue()) return null;
      final now = _now();
      final result = await cache.cleanup(
        account,
        now: now,
        maxAge: interval,
        shownKeys: _shown.keysOf(account),
      );
      try {
        await (await _p()).setInt(lastRunKey, now.millisecondsSinceEpoch);
      } catch (_) {
        // Not recorded: the next start or resume runs it again.
      }
      if (result.refresh.isNotEmpty && !isOffline()) {
        for (final key in result.refresh) {
          _shown.refresh(account, key);
        }
      }
      return result;
    } catch (_) {
      return null;
    } finally {
      _running = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(runIfDue());
  }

  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }
}
