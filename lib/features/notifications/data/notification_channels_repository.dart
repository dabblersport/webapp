// KAN-1048 (NOTIF-4): the caller's notification channels and their mutes,
// through the KAN-1045 RPCs only.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'models/notification_channel.dart';
import 'notification_settings_repository_impl.dart'
    show NotificationSettingsRpc;

abstract class NotificationChannelsRepository {
  /// Every channel with the caller's mute (`rpc_list_notification_channels`).
  Future<Result<List<NotificationChannel>, Failure>> list();

  /// Mutes or unmutes one channel (`rpc_set_notification_channel_muted`).
  /// An unmutable channel fails (22023).
  Future<Result<bool, Failure>> setChannelMuted(String channelKey, bool muted);

  /// Mutes or unmutes every mutable channel of a group
  /// (`rpc_set_notification_group_muted`).
  Future<Result<int, Failure>> setGroupMuted(String groupKey, bool muted);
}

class NotificationChannelsRepositoryImpl
    implements NotificationChannelsRepository {
  NotificationChannelsRepositoryImpl(SupabaseClient client)
    : _rpc = ((fn, {params}) => client.rpc(fn, params: params));

  /// A repository over a fake RPC call.
  NotificationChannelsRepositoryImpl.withRpc(this._rpc);

  final NotificationSettingsRpc _rpc;

  @override
  Future<Result<List<NotificationChannel>, Failure>> list() =>
      Result.guard(() async {
        final Object? raw = await _rpc(
          SupabaseConfig.rpcListNotificationChannels,
        );
        if (raw is! List) throw const FormatException('channels: not a list');
        return [
          for (final Object? r in raw)
            NotificationChannel.fromJson(Map<String, dynamic>.from(r as Map)),
        ];
      }, Failure.from);

  @override
  Future<Result<bool, Failure>> setChannelMuted(
    String channelKey,
    bool muted,
  ) => Result.guard(
    () async =>
        (await _rpc(
              SupabaseConfig.rpcSetNotificationChannelMuted,
              params: {'p_channel_key': channelKey, 'p_muted': muted},
            ))
            as bool? ??
        muted,
    Failure.from,
  );

  @override
  Future<Result<int, Failure>> setGroupMuted(String groupKey, bool muted) =>
      Result.guard(
        () async =>
            ((await _rpc(
                      SupabaseConfig.rpcSetNotificationGroupMuted,
                      params: {'p_group_key': groupKey, 'p_muted': muted},
                    ))
                    as num?)
                ?.toInt() ??
            0,
        Failure.from,
      );
}
