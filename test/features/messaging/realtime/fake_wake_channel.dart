import 'dart:async';

import 'package:dabbler/features/messaging/data/messaging_wake_channel.dart';

/// A scripted [WakeChannel]: no Supabase, no network. Tests push wakes and
/// status changes and read how often it was opened and closed.
class FakeWakeChannel extends WakeChannel {
  FakeWakeChannel(
    this.userId, {
    WakeChannelStatus status = WakeChannelStatus.connecting,
  }) : _status = status;

  final String userId;
  final _wakes = StreamController<MessagingWake>.broadcast(sync: true);
  final _statuses = StreamController<WakeChannelStatus>.broadcast(sync: true);
  WakeChannelStatus _status;
  int closeCalls = 0;

  bool get closed => closeCalls > 0;

  @override
  Stream<MessagingWake> get wakes => _wakes.stream;

  @override
  Stream<WakeChannelStatus> get statuses => _statuses.stream;

  @override
  WakeChannelStatus get status => _status;

  void emit(MessagingWake wake) => _wakes.add(wake);

  void setStatus(WakeChannelStatus status) {
    _status = status;
    _statuses.add(status);
  }

  @override
  Future<void> close() async {
    closeCalls++;
    _status = WakeChannelStatus.closed;
  }
}
