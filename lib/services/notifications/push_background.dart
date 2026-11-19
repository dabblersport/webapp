// KAN-1016: the background half of Android pushes. v15 sends RSVP, waitlist
// and message pushes to Android as data-only messages, so the app draws them
// itself — with their channel and action buttons — from the FCM background
// handler, which runs in its own isolate (no app state, no providers).

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:dabbler/l10n/app_localizations.dart';

import 'push_contract.dart';
import 'push_local_display.dart';

/// The action labels' language in the background isolate: the device's, when
/// the app has it (Arabic or English), else English.
Locale pushBackgroundLocale([Locale? device]) {
  final d = device ?? PlatformDispatcher.instance.locale;
  return AppLocalizations.supportedLocales.any(
        (l) => l.languageCode == d.languageCode,
      )
      ? Locale(d.languageCode)
      : const Locale('en');
}

/// Draws a data-only push from the background handler (Android only). A push
/// with a notification block is drawn by FCM itself and is left alone.
Future<void> drawBackgroundPush(
  RemoteMessage message, {
  FlutterLocalNotificationsPlugin? plugin,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final data = Map<String, dynamic>.from(message.data);
  if (!isDataOnlyPush(
    hasNotificationBlock: message.notification != null,
    data: data,
  )) {
    return;
  }
  final drawing = pushDrawingOf(data, collapseKey: message.collapseKey)!;
  final p = plugin ?? FlutterLocalNotificationsPlugin();
  await p.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
    ),
    onDidReceiveBackgroundNotificationResponse: pushBackgroundResponse,
  );
  final display = PushLocalDisplay(p);
  await display.createChannels();
  await display.show(
    data: data,
    title: drawing.title,
    body: drawing.body,
    channelId: drawing.channelId,
    tag: drawing.tag,
    l10n: lookupAppLocalizations(pushBackgroundLocale()),
  );
}

/// A notification response delivered to a background isolate. Every action
/// opens the app (`showsUserInterface`), which then receives the response as
/// its launch details or its foreground callback and runs it there
/// ([PushLocalDisplay.handleResponse]); nothing runs here without the app.
@pragma('vm:entry-point')
void pushBackgroundResponse(NotificationResponse response) {
  debugPrint(
    'Push response in background: ${response.actionId ?? 'tap'} '
    '(handled when the app opens)',
  );
}
