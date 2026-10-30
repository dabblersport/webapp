import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerMotion;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/offline/sync/queueable_settings.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/services/connectivity_service.dart';
import 'package:dabbler/core/sync/pending_settings_store.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';

/// Where a queued setting stands (KAN-608). A setting with no entry is synced.
enum SettingSyncState {
  /// Saved on the device, not sent yet (offline, or an attempt is running).
  pending,

  /// The last attempt to send it failed; it is retried on the next reconnect
  /// or app resume, on a bounded backoff, or when the user taps retry.
  failed,
}

/// What [SettingsSyncNotifier.submit] did.
enum SubmitOutcome {
  /// The server has it.
  synced,

  /// Kept on the device for later: offline, or the attempt failed.
  queued,

  /// The server held a newer value, written after this edit: it won.
  serverWon,

  /// Not a queueable setting (KAN-657): nothing stored, the caller shows the
  /// normal network error.
  refused,

  /// The server refused the edit for a reason other than the network
  /// (validation, permission): dropped, the server value restored.
  dropped,
}

/// The offline settings queue and its sync (KAN-608).
///
/// Every account-level setting edit is applied on the device first and handed
/// to [submit], which stores it with its edit timestamp and sends it when it
/// can. Pending edits are sent in timestamp order on a reconnect, on app
/// resume, on a bounded-backoff retry and on an explicit [retry].
///
/// **Conflict rule: last write wins by edit timestamp.** Before sending, the
/// handler reads the server row's `updated_at`. If it is later than the local
/// edit's timestamp, another device wrote after this edit: the local edit is
/// dropped and the server value is adopted. Otherwise the edit is sent and
/// stamps the row with its own edit time, so a device that edited later wins
/// no matter which one reaches the server first. A setting whose server side
/// has no per-setting timestamp (language) is sent unconditionally.
class SettingsSyncNotifier extends StateNotifier<Map<String, SettingSyncState>>
    with WidgetsBindingObserver {
  SettingsSyncNotifier({
    required this.accountId,
    required this.handlers,
    required this.isOffline,
    PendingSettingsStore store = const PendingSettingsStore(),
    DateTime Function()? now,
    bool observeLifecycle = true,
    this.maxAutoRetries = 5,
    this.onNotice,
  }) : _store = store,
       _now = now ?? (() => DateTime.now().toUtc()),
       super(const {}) {
    if (observeLifecycle) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      } catch (_) {}
    }
    SettingsSyncBridge._active = this;
    unawaited(_start());
  }

  final String? accountId;
  final Map<String, SettingSyncHandler> handlers;
  final bool Function() isOffline;
  final int maxAutoRetries;

  /// Told when a queued change was overridden or refused (KAN-657), and with
  /// null when the setting's notice is cleared by a new edit.
  final void Function(String key, SettingNotice? notice)? onNotice;
  final PendingSettingsStore _store;
  final DateTime Function() _now;

  bool _observing = false;
  Timer? _retryTimer;
  bool _syncing = false;
  final _adopted = StreamController<String>.broadcast();

  /// Fires with the setting key when the server's newer value was adopted, so
  /// the screen showing it can reload.
  Stream<String> get adopted => _adopted.stream;

  /// The backoff before attempt number [attempts]+1: doubles from 5 s, capped
  /// at 5 minutes.
  Duration backoffFor(int attempts) {
    final capped = attempts > 6 ? 6 : attempts;
    final wait = DabblerMotion.timeoutShort * (1 << capped);
    final cap = DabblerMotion.timeoutNetwork * 30;
    return wait > cap ? cap : wait;
  }

  Future<void> _start() async {
    final account = accountId;
    if (account == null) return;
    await _store.wipe(keepAccountId: account);
    final edits = await _store.load(account);
    if (!mounted) return;
    state = {
      for (final e in edits.values)
        e.key: e.attempts > 0
            ? SettingSyncState.failed
            : SettingSyncState.pending,
    };
    if (edits.isNotEmpty && !isOffline()) await syncAll(force: true);
  }

  /// The value of a queued edit, so a screen that reloads from the server
  /// keeps showing what the user last set. Null when nothing is queued.
  Future<Map<String, dynamic>?> pendingValue(String key) async {
    final account = accountId;
    if (account == null) return null;
    return (await _store.load(account))[key]?.value;
  }

  bool hasPending(String key) => state.containsKey(key);

  /// Stores the edit and tries to send it now. Never throws; the caller has
  /// already applied the change on the device.
  Future<SubmitOutcome> submit(
    String key,
    Map<String, dynamic> value, {
    DateTime? editedAt,
  }) async {
    if (!isQueueableSetting(key)) return SubmitOutcome.refused;
    final account = accountId;
    if (account == null) return SubmitOutcome.queued;
    onNotice?.call(key, null);
    final edit = PendingSettingEdit(
      key: key,
      value: value,
      editedAt: editedAt ?? _now(),
    );
    await _store.put(account, edit);
    if (!mounted) return SubmitOutcome.queued;
    state = {...state, key: SettingSyncState.pending};
    if (isOffline()) return SubmitOutcome.queued;
    return _attempt(account, key);
  }

  Future<SubmitOutcome> _attempt(String account, String key) async {
    final edit = (await _store.load(account))[key];
    final handler = handlers[key];
    if (edit == null) return SubmitOutcome.synced;
    if (handler == null) return SubmitOutcome.queued;
    try {
      final server = await handler
          .serverUpdatedAt(account)
          .timeout(kRequestTimeout);
      if (server != null && server.isAfter(edit.editedAt)) {
        await handler.adoptServer(account).timeout(kRequestTimeout);
        await _store.remove(account, key, ifEditedAt: edit.editedAt);
        await _settle(account, key);
        if (mounted) _adopted.add(key);
        onNotice?.call(key, SettingNotice.updatedElsewhere);
        return SubmitOutcome.serverWon;
      }
      await handler.push(account, edit).timeout(kRequestTimeout);
      await _store.remove(account, key, ifEditedAt: edit.editedAt);
      await _settle(account, key);
      return SubmitOutcome.synced;
    } catch (e) {
      if (!isRetryableSettingFailure(e)) {
        // Validation or permission: it will not pass on a retry. Drop the
        // edit and show the server's value again.
        await _store.remove(account, key, ifEditedAt: edit.editedAt);
        try {
          await handler.adoptServer(account).timeout(kRequestTimeout);
        } catch (_) {}
        await _settle(account, key);
        if (mounted) _adopted.add(key);
        onNotice?.call(key, SettingNotice.rejected);
        return SubmitOutcome.dropped;
      }
      await _store.markFailed(account, key, edit.editedAt, _now());
      if (mounted) state = {...state, key: SettingSyncState.failed};
      _scheduleRetry(account);
      return SubmitOutcome.queued;
    }
  }

  /// After a send: the setting is synced unless a newer edit is queued.
  Future<void> _settle(String account, String key) async {
    final left = (await _store.load(account))[key];
    if (!mounted) return;
    final next = Map<String, SettingSyncState>.of(state);
    if (left == null) {
      next.remove(key);
    } else {
      next[key] = SettingSyncState.pending;
    }
    state = next;
  }

  /// Sends every pending edit in edit-timestamp order. [force] ignores the
  /// backoff (reconnect, resume, tap on retry); the retry timer does not.
  Future<void> syncAll({bool force = false}) async {
    final account = accountId;
    if (account == null || _syncing || isOffline()) return;
    _syncing = true;
    try {
      final edits = (await _store.load(account)).values.toList()
        ..sort((a, b) => a.editedAt.compareTo(b.editedAt));
      for (final edit in edits) {
        if (!mounted) return;
        if (!force && edit.lastAttemptAt != null) {
          final due = edit.lastAttemptAt!.add(backoffFor(edit.attempts - 1));
          if (due.isAfter(_now())) continue;
        }
        await _attempt(account, edit.key);
      }
    } finally {
      _syncing = false;
    }
  }

  /// Tap on the inline "not synced" hint.
  Future<void> retry(String key) async {
    final account = accountId;
    if (account == null || isOffline()) return;
    await _attempt(account, key);
  }

  void _scheduleRetry(String account) {
    _retryTimer?.cancel();
    unawaited(() async {
      final edits = (await _store.load(
        account,
      )).values.where((e) => e.attempts > 0 && e.attempts <= maxAutoRetries);
      if (!mounted || edits.isEmpty) return;
      DateTime? next;
      for (final e in edits) {
        final due = e.lastAttemptAt!.add(backoffFor(e.attempts - 1));
        if (next == null || due.isBefore(next)) next = due;
      }
      var wait = next!.difference(_now());
      if (wait.isNegative) wait = DabblerMotion.timeoutShort;
      _retryTimer = Timer(wait, () => unawaited(syncAll()));
    }());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      unawaited(syncAll(force: true));
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    if (identical(SettingsSyncBridge._active, this)) {
      SettingsSyncBridge._active = null;
    }
    _adopted.close();
    super.dispose();
  }
}

/// Lets code outside Riverpod (the theme service, the locale notifier) hand an
/// edit to the running sync, and skip a server hydrate that would overwrite a
/// queued edit.
class SettingsSyncBridge {
  SettingsSyncBridge._();

  static SettingsSyncNotifier? _active;

  /// Queues [value] for [key]; false when no sync is running (signed out, a
  /// unit test), in which case the caller keeps its own direct write.
  static Future<bool> submit(String key, Map<String, dynamic> value) async {
    final active = _active;
    if (active == null || active.accountId == null) return false;
    await active.submit(key, value);
    return true;
  }

  /// A queued edit of [key] exists, so the server copy is older than the
  /// device's: a server hydrate must not overwrite the local value.
  static Future<bool> hasPendingEdit(String key) async {
    final active = _active;
    if (active == null) return false;
    return await active.pendingValue(key) != null;
  }
}

/// The queue for the signed-in account. Rebuilt on an account switch, which
/// discards every other account's queue.
final settingsSyncProvider =
    StateNotifierProvider<SettingsSyncNotifier, Map<String, SettingSyncState>>((
      ref,
    ) {
      final notifier = SettingsSyncNotifier(
        accountId: ref.watch(cacheAccountIdProvider),
        handlers: defaultSettingSyncHandlers(),
        isOffline: () =>
            ref.read(connectivityProvider) == ConnectionStatus.offline,
        onNotice: (key, notice) {
          final notices = ref.read(settingNoticesProvider.notifier);
          final next = Map<String, SettingNotice>.of(notices.state);
          if (notice == null) {
            next.remove(key);
          } else {
            next[key] = notice;
          }
          notices.state = next;
        },
      );
      ref.listen<AsyncValue<void>>(connectivityReconnectProvider, (_, _) {
        unawaited(notifier.syncAll(force: true));
      });
      return notifier;
    });
