// KAN-1048 (NOTIF-4): one notification channel (KAN-1045,
// `rpc_list_notification_channels`). Groups are the kind categories.

import 'package:equatable/equatable.dart';

/// One row of `rpc_list_notification_channels`.
class NotificationChannel extends Equatable {
  const NotificationChannel({
    required this.key,
    required this.groupKey,
    required this.labelEn,
    required this.labelAr,
    required this.canMute,
    required this.muted,
    required this.sortOrder,
  });

  factory NotificationChannel.fromJson(Map<String, dynamic> j) =>
      NotificationChannel(
        key: j['channel_key'] as String,
        groupKey: j['group_key'] as String,
        labelEn: (j['label_en'] as String?) ?? j['channel_key'] as String,
        labelAr: (j['label_ar'] as String?) ?? (j['label_en'] as String?) ?? '',
        canMute: (j['can_mute'] as bool?) ?? true,
        muted: (j['muted'] as bool?) ?? false,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );

  final String key;
  final String groupKey;
  final String labelEn;
  final String labelAr;
  final bool canMute;
  final bool muted;
  final int sortOrder;

  /// On = notifications on this channel are delivered.
  bool get on => !muted;

  /// The label for [languageCode] (`ar` reads `label_ar`).
  String label(String languageCode) =>
      languageCode == 'ar' && labelAr.isNotEmpty ? labelAr : labelEn;

  NotificationChannel withMuted(bool value) => NotificationChannel(
    key: key,
    groupKey: groupKey,
    labelEn: labelEn,
    labelAr: labelAr,
    canMute: canMute,
    muted: canMute && value,
    sortOrder: sortOrder,
  );

  @override
  List<Object?> get props => [
    key,
    groupKey,
    labelEn,
    labelAr,
    canMute,
    muted,
    sortOrder,
  ];
}

/// One group of channels, in `sort_order`.
class NotificationChannelGroup {
  const NotificationChannelGroup(this.key, this.channels);

  final String key;
  final List<NotificationChannel> channels;

  /// The group switch is on when any channel in it is on.
  bool get anyOn => channels.any((c) => c.on);

  /// False for a group none of whose channels can be muted (security).
  bool get canMute => channels.any((c) => c.canMute);
}

/// Groups [channels] by `group_key`; groups and channels both follow
/// `sort_order` (a group sorts by its first channel).
List<NotificationChannelGroup> groupNotificationChannels(
  List<NotificationChannel> channels,
) {
  final sorted = [...channels]
    ..sort((a, b) {
      final int c = a.sortOrder.compareTo(b.sortOrder);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  final Map<String, List<NotificationChannel>> byGroup = {};
  for (final c in sorted) {
    (byGroup[c.groupKey] ??= <NotificationChannel>[]).add(c);
  }
  return [
    for (final e in byGroup.entries) NotificationChannelGroup(e.key, e.value),
  ];
}
