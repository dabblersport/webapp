import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';

import '../../data/models/notification_settings.dart';
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

/// Loads notification settings on construction and persists every mutation
/// optimistically (updating the UI immediately, then writing through; on
/// failure the previous value is restored and [NotificationSettingsState.error]
/// is set).
class NotificationSettingsController
    extends StateNotifier<NotificationSettingsState> {
  /// [sync] / [accountId] (KAN-608): an edit is applied on the device at
  /// once, stored in the offline queue with its edit time and sent when the
  /// connection allows; without them an edit is written through and reverted
  /// on failure, as before.
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
  static final String _mirrorKey = settingsMirrorKey(
    SettingKeys.notifications,
  );

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

  Future<void> setPushEnabled(bool value) =>
      _mutate((s) => s.copyWith(pushEnabled: value));

  Future<void> setEmailEnabled(bool value) =>
      _mutate((s) => s.copyWith(emailEnabled: value));

  Future<void> setSmsEnabled(bool value) =>
      _mutate((s) => s.copyWith(smsEnabled: value));

  /// Toggle a group of `notification_kinds` keys on/off. [enabled] = not muted.
  Future<void> setKindsEnabled(List<String> kindKeys, bool enabled) =>
      _mutate((s) => s.withKindsMuted(kindKeys, !enabled));

  Future<void> setQuietHours(int startMin, int endMin) =>
      _mutate((s) => s.copyWith(quietStartMin: startMin, quietEndMin: endMin));

  Future<void> clearQuietHours() =>
      _mutate((s) => s.copyWith(quietStartMin: null, quietEndMin: null));

  Future<void> setAllowHighPriorityOverride(bool value) =>
      _mutate((s) => s.copyWith(allowHighPriorityOverride: value));

  /// Allow every push through quiet hours (supersedes the high-priority-only
  /// override in the server-side push trigger).
  Future<void> setAllowAllOverride(bool value) =>
      _mutate((s) => s.copyWith(allowAllOverride: value));

  /// Applies [change] optimistically, persists, and reverts on failure.
  Future<void> _mutate(
    NotificationSettings Function(NotificationSettings) change,
  ) async {
    final current = state.settings;
    if (current == null) return;

    final updated = change(current);

    if (_offlineFirst) {
      // KAN-608: applied on the device at once, kept in the offline queue.
      state = state.copyWith(settings: updated, isSaving: false, error: null);
      (_cache ?? OfflineCache.instance).write(
        _accountId!,
        _mirrorKey,
        updated.toJson(),
      );
      await _sync!.submit(SettingKeys.notifications, updated.toJson());
      return;
    }

    // Optimistic update.
    state = state.copyWith(settings: updated, isSaving: true, error: null);

    final result = await _repository.save(updated);
    result.fold(
      (failure) => state = state.copyWith(
        settings: current, // revert
        isSaving: false,
        error: failure.message,
      ),
      (saved) =>
          state = state.copyWith(settings: saved, isSaving: false, error: null),
    );
  }
}
