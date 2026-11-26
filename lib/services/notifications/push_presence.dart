// KAN-992 (W1-F6): what the app tells the push layer about itself, and the
// native `dabbler/push` channel (iOS): the chat open on screen (no alert for
// it), whether the in-app banner (W1-F7) presents foreground rows, the
// app-icon badge, and the iOS notification actions the AppDelegate forwards.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'push_contract.dart';

/// One action tapped on a notification (iOS forwards it from the
/// AppDelegate; Android from flutter_local_notifications).
@immutable
class PushActionEvent {
  const PushActionEvent(this.action, this.data, {this.text});

  final PushActionId action;
  final Map<String, dynamic> data;

  /// The reply text (Reply only).
  final String? text;
}

/// A push that arrived while the app is in the foreground, with its de-dup
/// key: the in-app banner (W1-F7) uses the same key so a pop-up and a push
/// never both show.
@immutable
class ForegroundPush {
  const ForegroundPush(
    this.data, {
    required this.dedupeKey,
    required this.alerted,
  });

  final Map<String, dynamic> data;
  final String? dedupeKey;

  /// Whether the system alert was shown for it.
  final bool alerted;
}

class PushPresence {
  PushPresence._();

  static final PushPresence instance = PushPresence._();

  static const MethodChannel channel = MethodChannel('dabbler/push');

  /// The chat open on screen, from the router (main.dart's push section).
  OpenChat _openChat = OpenChat.none;
  OpenChat get openChat => _openChat;

  /// W1-F7 sets this when its banner presents foreground rows; the system
  /// alert then steps aside (Android here; iOS in the AppDelegate, told
  /// through the channel).
  bool _inAppBannerShows = false;
  bool get inAppBannerShows => _inAppBannerShows;
  set inAppBannerShows(bool shows) {
    if (shows == _inAppBannerShows) return;
    _inAppBannerShows = shows;
    _invoke('setBannerShows', shows);
  }

  final StreamController<ForegroundPush> _foreground =
      StreamController<ForegroundPush>.broadcast();

  /// Every foreground push and whether it alerted (W1-F7 listens).
  Stream<ForegroundPush> get foregroundPushes => _foreground.stream;

  final StreamController<PushActionEvent> _actions =
      StreamController<PushActionEvent>.broadcast();

  /// Actions tapped on notifications.
  Stream<PushActionEvent> get actions => _actions.stream;

  final StreamController<void> _openSettings =
      StreamController<void>.broadcast();

  /// KAN-1047: iOS Settings > Dabbler > Notifications > "Dabbler Notification
  /// Settings" was tapped; the app opens [notificationSettingsRoute].
  Stream<void> get openSettingsRequests => _openSettings.stream;

  /// The in-app notification settings screen.
  static const String notificationSettingsRoute = '/settings/notifications';

  bool _settingsPending = false;

  void _requestOpenSettings() {
    if (_openSettings.hasListener) {
      _openSettings.add(null);
    } else {
      _settingsPending = true;
    }
  }

  /// Whether the settings link was tapped before anything listened (a cold
  /// start from it); clears it.
  bool takePendingOpenSettings() {
    final pending = _settingsPending;
    _settingsPending = false;
    return pending;
  }

  bool _nativeWired = false;

  void reportForeground(ForegroundPush push) => _foreground.add(push);
  void reportAction(PushActionEvent event) => _actions.add(event);

  /// The router moved: remember the open chat and tell iOS, which decides
  /// foreground presentation natively.
  void setOpenChat(OpenChat chat) {
    if (_openChat.conversationId == chat.conversationId &&
        _openChat.gameId == chat.gameId &&
        _openChat.meetupId == chat.meetupId) {
      return;
    }
    _openChat = chat;
    _invoke('setOpenChat', <String, String?>{
      'conversation_id': chat.conversationId,
      'game_id': chat.gameId,
      'meetup_id': chat.meetupId,
    });
  }

  /// The app-icon badge: the server's unread count; 0 clears it (iOS through
  /// the AppDelegate; Android launchers follow the notifications).
  void setBadge(int count) => _invoke('setBadge', count < 0 ? 0 : count);

  /// Re-registers the iOS categories with the action titles in the app's
  /// language ({action id: title}); the AppDelegate registers English ones at
  /// launch.
  void setActionTitles(Map<String, String> titles) =>
      _invoke('setCategories', titles);

  /// Listens to the AppDelegate's forwarded iOS actions and drains the ones
  /// it kept while the engine was not running (a cold start from an action).
  Future<void> wireNative() async {
    if (_nativeWired || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _nativeWired = true;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'action') _onNativeAction(call.arguments);
      if (call.method == 'openSettings') _requestOpenSettings();
      return null;
    });
    try {
      final pending = await channel.invokeListMethod<Object?>('pendingActions');
      for (final a in pending ?? const <Object?>[]) {
        _onNativeAction(a);
      }
    } catch (e) {
      debugPrint('Push presence: no pending actions ($e)');
    }
    // KAN-1047: the settings link tapped before Dart was listening.
    try {
      if (await channel.invokeMethod<bool>('pendingOpenSettings') ?? false) {
        _requestOpenSettings();
      }
    } catch (e) {
      debugPrint('Push presence: no pending settings link ($e)');
    }
  }

  void _onNativeAction(Object? raw) {
    final event = parseNativeAction(raw);
    if (event != null) reportAction(event);
  }

  /// `{action, data, text}` from the AppDelegate, or null.
  @visibleForTesting
  static PushActionEvent? parseNativeAction(Object? raw) {
    if (raw is! Map) return null;
    final action = PushActionId.parse(raw['action'] as String?);
    if (action == null) return null;
    final data = <String, dynamic>{
      for (final e in ((raw['data'] as Map?) ?? const {}).entries)
        '${e.key}': e.value,
    };
    final text = raw['text'];
    return PushActionEvent(action, data, text: text is String ? text : null);
  }

  void _invoke(String method, Object? args) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    channel.invokeMethod<void>(method, args).catchError((Object e) {
      debugPrint('Push presence: $method failed ($e)');
    });
  }
}
