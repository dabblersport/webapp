// KAN-1048 (NOTIF-4): per-channel and per-group mutes. Every change is
// applied at once and restored if the RPC fails; the caller shows the error.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/notifications/data/models/notification_channel.dart';
import 'package:dabbler/features/notifications/data/notification_channels_repository.dart';

class NotificationChannelsState {
  const NotificationChannelsState({this.channels, this.loadFailed = false});

  /// Null while loading.
  final List<NotificationChannel>? channels;
  final bool loadFailed;

  List<NotificationChannelGroup> get groups =>
      groupNotificationChannels(channels ?? const <NotificationChannel>[]);
}

class NotificationChannelsController
    extends StateNotifier<NotificationChannelsState> {
  NotificationChannelsController(this._repo)
    : super(const NotificationChannelsState()) {
    load();
  }

  final NotificationChannelsRepository _repo;

  Future<void> load() async {
    final result = await _repo.list();
    if (!mounted) return;
    state = result.fold(
      (_) => const NotificationChannelsState(loadFailed: true),
      (list) => NotificationChannelsState(channels: list),
    );
  }

  /// Switches one channel on or off. Returns false (and restores the old
  /// value) when the server refused.
  Future<bool> setChannelOn(String channelKey, bool on) async {
    return _optimistic(
      (c) => c.key == channelKey,
      !on,
      () async => (await _repo.setChannelMuted(channelKey, !on)).isSuccess,
    );
  }

  /// Switches every mutable channel of a group on or off.
  Future<bool> setGroupOn(String groupKey, bool on) async {
    return _optimistic(
      (c) => c.groupKey == groupKey,
      !on,
      () async => (await _repo.setGroupMuted(groupKey, !on)).isSuccess,
    );
  }

  Future<bool> _optimistic(
    bool Function(NotificationChannel) match,
    bool muted,
    Future<bool> Function() call,
  ) async {
    final List<NotificationChannel>? before = state.channels;
    if (before == null) return false;
    state = NotificationChannelsState(
      channels: [for (final c in before) match(c) ? c.withMuted(muted) : c],
    );
    final bool ok = await call();
    if (!ok && mounted) state = NotificationChannelsState(channels: before);
    return ok;
  }
}
