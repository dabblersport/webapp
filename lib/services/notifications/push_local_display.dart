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
  PushImportance.low => Importance.low,
  PushImportance.defaultLevel => Importance.defaultImportance,
  PushImportance.high => Importance.high,
  PushImportance.max => Importance.max,
};

class PushLocalDisplay {
  PushLocalDisplay(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Creates every channel KAN-979 sends to (and drops the pre-KAN-992 one).
  Future<void> createChannels() async {
    final android = _android;
    if (android == null) return;
    for (final c in PushChannels.all) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          c.id,
          c.name,
          description: c.description,
          importance: _importance(c.importance),
          playSound: c.sound,
          enableVibration: c.sound,
          showBadge: c.id != PushChannels.quiet,
        ),
      );
    }
    try {
      await android.deleteNotificationChannel('default_channel');
    } catch (_) {}
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
    final channel = PushChannels.byId(
      PushChannels.of(data, serverChannelId: channelId),
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
      priority: channel.importance == PushImportance.low
          ? Priority.low
          : Priority.high,
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
