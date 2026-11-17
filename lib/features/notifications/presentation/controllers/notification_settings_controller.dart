import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';

import '../../data/models/notification_settings.dart';
import '../../data/models/notification_settings_keys.dart';
import '../../data/notification_settings_repository.dart';

/// UI state for the notification settings screen.
class NotificationSettingsState {
  const NotificationSettingsState({
    this.settings,
    this.isLoading = true,
    this.isSaving = false,
    this.error,
  });

  /// Current settings (null until the first load completes).
  final NotificationSettings? settings;
  final bool isLoading;
  final bool isSaving;

  /// Last load/save error message, if any.
  final String? error;

  NotificationSettingsState copyWith({
    NotificationSettings? settings,
    bool? isLoading,
    bool? isSaving,
    Object? error = _sentinel,
  }) {
    return NotificationSettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

/// What a quiet-hours save did (KAN-991).
enum QuietHoursSave { saved, invalid, failed }

/// The error set when a security kind would be muted (the server's 22023,
/// refused on the device first).
const String kSecurityMuteRefused = 'security-mute-refused';

/// Loads notification settings on construction and persists every mutation
/// optimistically: the UI updates at once, the change is written, and on
/// failure the previous value is restored and
/// [NotificationSettingsState.error] is set.
class NotificationSettingsController
    extends StateNotifier<NotificationSettingsState> {
  /// [sync] / [accountId] (KAN-608): an edit is applied on the device at
  /// once, stored in the offline queue with its edit time and sent when the
  /// connection allows; without them an edit is written through as a partial
  /// RPC patch and reverted on failure.
  NotificationSettingsController(
    this._repository, {
    SettingsSyncNotifier? sync,
    String? accountId,
    OfflineCache? cache,
  }) : _sync = sync,
       _accountId = accountId,
       _cache = cache,
       super(const NotificationSettingsState()) {
    load();
  }

  final NotificationSettingsRepository _repository;
  final SettingsSyncNotifier? _sync;
  final String? _accountId;
  final OfflineCache? _cache;

  bool get _offlineFirst => _sync != null && _accountId != null;
  static final String _mirrorKey = settingsMirrorKey(SettingKeys.notifications);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    if (_offlineFirst) {
      // An edit still waiting for the server is newer than the server's copy.
      final pending = await _sync!.pendingValue(SettingKeys.notifications);
      if (!mounted) return;
      if (pending != null) {
        state = state.copyWith(
          settings: NotificationSettings.fromJson(pending),
          isLoading: false,
          error: null,
        );
        return;
      }
    }
    final result = await _repository.load();
    if (!mounted) return;
    if (_offlineFirst) {
      final mirror = _cache ?? OfflineCache.instance;
      if (result.isSuccess) {
        mirror.write(
          _accountId!,
          _mirrorKey,
          result.fold((_) => null, (s) => s.toJson()),
        );
      } else {
        // Offline: the last copy the server gave this account.
        final hit = await mirror.read(_accountId!, _mirrorKey);
        if (!mounted) return;
        if (hit != null) {
          state = state.copyWith(
            settings: NotificationSettings.fromJson(
              Map<String, dynamic>.from(hit.payload as Map),
            ),
            isLoading: false,
            error: null,
          );
          return;
        }
      }
    }
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (settings) => state = state.copyWith(
        settings: settings,
        isLoading: false,
        error: null,
      ),
    );
  }

  /// The push master switch.
  Future<void> setPushEnabled(bool value) =>
      _mutate((s) => s.copyWith(pushEnabled: value), {'push_enabled': value});

  /// One category's in-app or push switch ([NotifChannel]).
  Future<void> setCategory(String category, String channel, bool on) =>
      _mutate((s) => s.withCategory(category, channel, on), {
        'category_prefs': {
          category: {channel: on},
        },
      });

  /// One reminder rung ([NotifRung]) of Going or Interested.
  Future<void> setRung(String group, String rung, bool on) =>
      _mutate((s) => s.withRung(group, rung, on), {
        'reminder_rungs': {
          group: {rung: on},
        },
      });

  /// The message preview: sender name only, or sender name and message.
  Future<void> setPreviewSenderOnly(bool senderOnly) {
    final value = senderOnly
        ? NotifPreview.senderOnly
        : NotifPreview.senderAndMessage;
    return _mutate((s) => s.copyWith(messagePreview: value), {
      'message_preview': value,
    });
  }

  /// Saves the quiet-hours editor. Off clears the window; on needs a start
  /// different from the end (the server rejects equal ones with 22023).
  Future<QuietHoursSave> saveQuietHours({
    required bool enabled,
    required int startMin,
    required int endMin,
  }) async {
    if (enabled && startMin == endMin) return QuietHoursSave.invalid;
    final ok = await _mutate(
      (s) => enabled
          ? s.copyWith(quietStartMin: startMin, quietEndMin: endMin)
          : s.copyWith(quietStartMin: null, quietEndMin: null),
      enabled
          ? {
              'quiet_hours_enabled': true,
              'quiet_start_min': startMin,
              'quiet_end_min': endMin,
            }
          : {'quiet_hours_enabled': false},
    );
    return ok ? QuietHoursSave.saved : QuietHoursSave.failed;
  }

  /// Mutes or unmutes [kindKeys]. Muting a security (unmutable) kind is
  /// refused here, before the server would refuse it: nothing changes and
  /// [NotificationSettingsState.error] is [kSecurityMuteRefused].
  Future<bool> setKindsMuted(List<String> kindKeys, bool muted) async {
    if (muted && kindKeys.any(notificationKindIsUnmutable)) {
      state = state.copyWith(error: kSecurityMuteRefused);
      return false;
    }
    return _mutate((s) => s.withKindsMuted(kindKeys, muted), null);
  }

  /// Toggle a group of `notification_kinds` keys on/off. [enabled] = not muted.
  Future<bool> setKindsEnabled(List<String> kindKeys, bool enabled) =>
      setKindsMuted(kindKeys, !enabled);

  /// Applies [change] optimistically and persists it: [patch] through the RPC
  /// (null sends the changed `muted_kinds`), or the whole value through the
  /// offline queue. Reverts on failure. True when the change stands.
  Future<bool> _mutate(
    NotificationSettings Function(NotificationSettings) change,
    Map<String, dynamic>? patch,
  ) async {
    final current = state.settings;
    if (current == null) return false;

    final updated = change(current);

    if (_offlineFirst) {
      // KAN-608: applied on the device at once, kept in the offline queue.
      state = state.copyWith(settings: updated, isSaving: false, error: null);
      (_cache ?? OfflineCache.instance).write(
        _accountId!,
        _mirrorKey,
        updated.toJson(),
      );
      final outcome = await _sync!.submit(
        SettingKeys.notifications,
        updated.toJson(),
      );
      if (outcome == SubmitOutcome.dropped && mounted) {
        // The server refused it (validation): show the previous value.
        state = state.copyWith(
          settings: current,
          error: 'rejected',
          isSaving: false,
        );
        return false;
      }
      return true;
    }

    // Optimistic update.
    state = state.copyWith(settings: updated, isSaving: true, error: null);

    final result = await _repository.update(
      patch ?? {'muted_kinds': updated.mutedKinds},
    );
    if (!mounted) return result.isSuccess;
    return result.fold(
      (failure) {
        state = state.copyWith(
          settings: current, // revert
          isSaving: false,
          error: failure.message,
        );
        return false;
      },
      (saved) {
        state = state.copyWith(settings: saved, isSaving: false, error: null);
        return true;
      },
    );
  }
}
