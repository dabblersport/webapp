import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  NotificationSettingsController(this._repository)
      : super(const NotificationSettingsState()) {
    load();
  }

  final NotificationSettingsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.load();
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
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

  /// Applies [change] optimistically, persists, and reverts on failure.
  Future<void> _mutate(
    NotificationSettings Function(NotificationSettings) change,
  ) async {
    final current = state.settings;
    if (current == null) return;

    final updated = change(current);
    // Optimistic update.
    state = state.copyWith(settings: updated, isSaving: true, error: null);

    final result = await _repository.save(updated);
    result.fold(
      (failure) => state = state.copyWith(
        settings: current, // revert
        isSaving: false,
        error: failure.message,
      ),
      (saved) => state = state.copyWith(
        settings: saved,
        isSaving: false,
        error: null,
      ),
    );
  }
}
