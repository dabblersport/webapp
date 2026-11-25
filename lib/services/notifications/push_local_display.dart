// KAN-992 (W1-F6): Android's side of a push the app draws itself — the
// channels (created up front so a background FCM push lands in the right one)
// and a foreground push shown on its channel with its category's actions.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:dabbler/l10n/app_localizations.dart';

import 'push_contract.dart';
import 'push_presence.dart';

/// An action's label in the app's language (also sent to iOS for its
/// categories).
String pushActionLabel(PushActionId a, AppLocalizations l) => switch (a) {
  PushActionId.reply => l.notif_action_reply,
  PushActionId.markRead => l.notif_menu_mark_read,
  PushActionId.going => l.notif_action_going,
  PushActionId.notGoing => l.notif_action_not_going,
  PushActionId.cancelPlace => l.notif_action_cancel_place,
};

/// Android action buttons, by id (a tap opens the app, which runs it).
AndroidNotificationAction androidActionFor(PushActionId a, AppLocalizations l) {
  final label = pushActionLabel(a, l);
  return AndroidNotificationAction(
    a.wire,
    label,
    showsUserInterface: true,
    cancelNotification: true,
    inputs: a.needsText
        ? <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(label: label),
          ]
        : const <AndroidNotificationActionInput>[],
  );
}

Importance _importance(PushImportance i) => switch (i) {
  PushImportance.min => Importance.min,
  PushImportance.low => Importance.low,
  PushImportance.defaultLevel => Importance.defaultImportance,
  PushImportance.high => Importance.high,
  PushImportance.max => Importance.max,
};

/// KAN-1046: a channel group's name in the app's language.
String pushChannelGroupName(AppLocalizations l, String group) =>
    switch (group) {
      'games' => l.notif_channels_group_games,
      'meetups' => l.notif_channels_group_meetups,
      'activities' => l.notif_channels_group_activities,
      'messages' => l.notif_channels_group_messages,
      'social' => l.notif_channels_group_social,
      'booking' => l.notif_channels_group_booking,
      'security' => l.notif_channels_group_security,
      'system' => l.notif_channels_group_system,
      _ => group,
    };

/// KAN-1046: the channel [id] as drawn in [l]'s language: a channel_key
/// channel named by its label and described by its group, else the quiet or
/// default channel.
PushChannel pushChannelFor(String id, AppLocalizations l) {
  if (id == PushChannels.quiet) return PushChannels.quietChannel;
  final spec = PushChannelTable.byKey(id);
  if (spec == null) return PushChannels.fallbackChannel;
  return PushChannel(
    spec.key,
    spec.label(l.localeName),
    pushChannelGroupName(l, spec.group),
    importance: spec.importance,
    group: spec.group,
  );
}

class PushLocalDisplay {
  PushLocalDisplay(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// KAN-1046: creates one group per [PushChannelTable.groups] and every
  /// channel inside its group, named in [l10n]'s language, plus the quiet and
  /// default channels; then (only once those exist) deletes the legacy flat
  /// category channels. Creating an existing channel again renames it, so the
  /// app calls this again when its language changes. With [onlyMissing]
  /// (the background isolate, which only knows the device's language) the
  /// channels that already exist keep their names.
  Future<void> createChannels(
    AppLocalizations l10n, {
    bool onlyMissing = false,
  }) async {
    final android = _android;
    if (android == null) return;
    Set<String> existing = const {};
    if (onlyMissing) {
      try {
        final list = await android.getNotificationChannels();
        existing = {for (final c in list ?? const []) c.id};
      } catch (_) {}
    }
    for (final g in PushChannelTable.groups) {
      await android.createNotificationChannelGroup(
        AndroidNotificationChannelGroup(g, pushChannelGroupName(l10n, g)),
      );
    }
    for (final c in [
      for (final spec in PushChannelTable.channels)
        pushChannelFor(spec.key, l10n),
      PushChannels.quietChannel,
      PushChannels.fallbackChannel,
    ]) {
      if (existing.contains(c.id)) continue;
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          c.id,
          c.name,
          description: c.description,
          groupId: c.group,
          importance: _importance(c.importance),
          playSound: c.sound,
          enableVibration: c.sound,
          showBadge: c.id != PushChannels.quiet,
        ),
      );
    }
    for (final old in [...PushChannelTable.legacy.keys, 'default_channel']) {
      try {
        await android.deleteNotificationChannel(old);
      } catch (_) {}
    }
  }

  /// Shows a foreground push on its channel with its actions. A push with the
  /// same collapse tag replaces the earlier one (G-01).
  Future<void> show({
    required Map<String, dynamic> data,
    required String? title,
    required String? body,
    String? channelId,
    String? tag,
    required AppLocalizations l10n,
  }) async {
    final channel = pushChannelFor(
      PushChannels.of(data, serverChannelId: channelId),
      l10n,
    );
    final secure = PushCategories.hidesPreview(data);
    final actions = PushCategories.actionsOf(data);
    final collapse =
        tag ?? (data['group_key'] as String?) ?? pushDedupeKey(data);
    final id =
        (collapse ?? '${DateTime.now().microsecondsSinceEpoch}').hashCode;
    final details = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: _importance(channel.importance),
      priority: !channel.sound ? Priority.low : Priority.high,
      playSound: channel.sound,
      tag: collapse,
      // G-08: a security push shows nothing private on the lock screen.
      visibility: secure
          ? NotificationVisibility.private
          : NotificationVisibility.public,
      actions: [for (final a in actions) androidActionFor(a, l10n)],
    );
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: details),
      payload: jsonEncode(data),
    );
  }

  /// A tap or an action on a notification the app drew: an action goes to
  /// [PushPresence.actions]; a plain tap returns its data for routing.
  static Map<String, dynamic>? handleResponse(NotificationResponse response) {
    final raw = response.payload;
    Map<String, dynamic> data = const {};
    if (raw != null && raw.isNotEmpty) {
      try {
        data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (e) {
        debugPrint('Push payload parse failed: $e');
      }
    }
    final action = PushActionId.parse(response.actionId);
    if (action != null) {
      PushPresence.instance.reportAction(
        PushActionEvent(action, data, text: response.input),
      );
      return null;
    }
    return data;
  }
}
