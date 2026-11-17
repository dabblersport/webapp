// KAN-993 (W1-F7): the in-app pop-up. When a notification row is inserted for
// the signed-in user while the app is in the foreground, one design-system
// banner shows its title (and body) at the top of the app; a tap opens the
// same target as the inbox row. Rows arriving together are queued and shown
// one at a time. Only INSERTs pop: an UPDATE that grows a grouped row (G-01)
// never does. The rules are in notification_popup_rules.dart; the de-dup key
// shared with the foreground push (KAN-992) is notification_presentation_key.

import 'dart:async';
import 'dart:collection';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/notification_realtime_service.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/services/notifications/push_presence.dart';

import 'notification_popup_rules.dart';
import 'notification_presentation_key.dart';

/// The rows inserted for [userId], as Realtime delivers them. Its own
/// insert-only channel: the inbox's service is not shared, because one
/// service holds one set of callbacks.
final notificationPopupArrivalsProvider = Provider.autoDispose
    .family<Stream<AppNotification>, String>((ref, userId) {
      final StreamController<AppNotification> out =
          StreamController<AppNotification>.broadcast();
      final NotificationRealtimeService service = NotificationRealtimeService();
      service.subscribe(userId: userId, onNewNotification: out.add);
      ref.onDispose(() {
        service.unsubscribe();
        out.close();
      });
      return out.stream;
    });

/// The de-dup ledger the presenter claims from (tests use their own).
final notificationPresentationLedgerProvider =
    Provider<NotificationPresentationLedger>(
      (ref) => NotificationPresentationLedger.instance,
    );

/// The pushes KAN-992 reports while the app is in the foreground.
final notificationForegroundPushesProvider = Provider<Stream<ForegroundPush>>(
  (ref) => PushPresence.instance.foregroundPushes,
);

/// Tells the push layer whether the pop-up owns foreground alerts
/// (`PushPresence.inAppBannerShows`); tests replace it.
final notificationPopupOwnsAlertsProvider = Provider<void Function(bool)>(
  (ref) =>
      (bool owns) => PushPresence.instance.inAppBannerShows = owns,
);

/// How long one pop-up stays up (the design system's toast duration).
const Duration kNotificationPopupDuration = DabblerToastSpec.defaultDuration;

class NotificationPopupPresenter extends ConsumerStatefulWidget {
  const NotificationPopupPresenter({
    super.key,
    required this.child,
    required this.currentLocation,
    required this.openRoute,
    this.now,
    this.isForeground,
  });

  final Widget child;

  /// The router's current location (the top of the stack).
  final String Function() currentLocation;

  /// Opens a route over the current one.
  final void Function(String route) openRoute;

  /// The clock; null is the current time (tests pin it).
  final DateTime Function()? now;

  /// Whether the app is in the foreground; null reads the binding.
  final bool Function()? isForeground;

  @override
  ConsumerState<NotificationPopupPresenter> createState() =>
      _NotificationPopupPresenterState();
}

class _Popup {
  const _Popup(this.notification, this.route);
  final AppNotification notification;
  final String? route;
}

class _NotificationPopupPresenterState
    extends ConsumerState<NotificationPopupPresenter> {
  final Queue<_Popup> _queue = Queue<_Popup>();
  _Popup? _current;
  Timer? _timer;
  Stream<AppNotification>? _stream;
  StreamSubscription<AppNotification>? _sub;
  StreamSubscription<ForegroundPush>? _pushSub;
  late final NotificationPresentationLedger _ledger;
  late final void Function(bool) _ownAlerts;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _ledger = ref.read(notificationPresentationLedgerProvider);
    _ownAlerts = ref.read(notificationPopupOwnsAlertsProvider);
    _ledger.popupPresenterMounted = true;
    _ownAlerts(true);
    _pushSub = ref.read(notificationForegroundPushesProvider).listen(_pushed);
  }

  @override
  void dispose() {
    _ledger.popupPresenterMounted = false;
    _ownAlerts(false);
    _timer?.cancel();
    _sub?.cancel();
    _pushSub?.cancel();
    super.dispose();
  }

  bool get _foreground {
    final bool Function()? f = widget.isForeground;
    if (f != null) return f();
    final AppLifecycleState? s = WidgetsBinding.instance.lifecycleState;
    return s == null || s == AppLifecycleState.resumed;
  }

  NotificationSettings? _settings() {
    if (_userId == null) return null;
    return ref.read(notificationSettingsControllerProvider).settings;
  }

  /// A row arrived through Realtime.
  void _arrived(AppNotification n) {
    if (!mounted) return;
    final NotificationPopupDecision d = decideNotificationPopup(
      n: n,
      location: widget.currentLocation(),
      now: (widget.now ?? DateTime.now)(),
      foreground: _foreground,
      settings: _settings(),
    );
    if (d != NotificationPopupDecision.show) return;
    final NotificationPresentationKey key = NotificationPresentationKey.of(
      notificationId: n.id,
      dedupeKey: n.dedupeKey,
    );
    if (!_ledger.claimPopup(key)) return;
    _queue.add(_Popup(n, notificationPopupRoute(n)));
    _next();
  }

  /// A push KAN-992 reported in the foreground. One that alerted is recorded
  /// as shown, so its Realtime row does not pop too. One that stepped aside
  /// for the pop-up shows as the pop-up when it carries a title (a push that
  /// beats its Realtime row); the row, arriving later, is then de-duplicated.
  void _pushed(ForegroundPush push) {
    if (!mounted) return;
    final Map<String, dynamic> data = push.data;
    final NotificationPresentationKey key =
        NotificationPresentationKey.fromPushData(data);
    if (push.alerted) {
      _ledger.recordSystemAlert(key);
      return;
    }
    String? s(String k) {
      final Object? v = data[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final String? title = s('title');
    final String? kind = s('kind_key');
    if (title == null || kind == null) return;
    _arrived(
      AppNotification(
        id: s('notification_id') ?? s('id') ?? '',
        toUserId: _userId ?? '',
        kindKey: kind,
        title: title,
        body: s('body'),
        actionRoute: s('action_route'),
        payload: data,
        dedupeKey: s('dedupe_key'),
        createdAt: (widget.now ?? DateTime.now)(),
      ),
    );
  }

  void _next() {
    if (_current != null || _queue.isEmpty) return;
    setState(() => _current = _queue.removeFirst());
    _timer?.cancel();
    _timer = Timer(kNotificationPopupDuration, _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _current = null);
    _next();
  }

  void _open(_Popup p) {
    final String? userId = _userId;
    final String id = p.notification.id;
    if (userId != null && id.isNotEmpty) {
      unawaited(
        ref
            .read(notificationsControllerProvider(userId).notifier)
            .markAsRead(id),
      );
    }
    _dismiss();
    final String? route = p.route;
    if (route != null) widget.openRoute(route);
  }

  void _follow(String? userId) {
    _userId = userId;
    if (userId == null) {
      _sub?.cancel();
      _sub = null;
      _stream = null;
      return;
    }
    final Stream<AppNotification> stream = ref.watch(
      notificationPopupArrivalsProvider(userId),
    );
    // Keep the settings alive while signed in (mutes, in-app switches,
    // quiet hours).
    ref.watch(notificationSettingsControllerProvider);
    if (identical(stream, _stream)) return;
    _sub?.cancel();
    _stream = stream;
    _sub = stream.listen(_arrived);
  }

  @override
  Widget build(BuildContext context) {
    _follow(ref.watch(notificationUserIdProvider));
    final _Popup? p = _current;
    return Stack(
      children: [
        widget.child,
        if (p != null)
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topCenter,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: DabblerSpacing.space4,
                  vertical: DabblerSpacing.space2,
                ),
                child: NotificationPopupBanner(
                  key: ValueKey<String>('notif-popup-${p.notification.id}'),
                  notification: p.notification,
                  onOpen: p.route == null ? null : () => _open(p),
                  previewSenderOnly: _settings()?.previewSenderOnly ?? false,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One pop-up: a design-system banner with the row's title and body. With a
/// target, the whole banner and its View action open it.
class NotificationPopupBanner extends StatelessWidget {
  const NotificationPopupBanner({
    super.key,
    required this.notification,
    this.onOpen,
    this.previewSenderOnly = false,
  });

  final AppNotification notification;
  final VoidCallback? onOpen;

  /// G-11: a message pop-up shows the sender only.
  final bool previewSenderOnly;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final NotificationKindSpec? spec = NotificationKinds.of(
      notification.kindKey,
    );
    final bool message =
        spec?.category == NotificationCategory.messages ||
        notification.kindKey.startsWith('message.');
    final String title = NotificationKinds.title(l10n, notification);
    final String? body = (message && previewSenderOnly)
        ? null
        : (NotificationKinds.body(
                l10n,
                notification.kindKey,
                notification.args.isEmpty ? null : notification.args,
              ) ??
              notification.body);
    final Widget banner = DabblerBanner(
      tone: DabblerBannerTone.info,
      icon: DabblerIcon(spec?.icon ?? 'notification'),
      title: title,
      message: (body == null || body.trim().isEmpty) ? null : body.trim(),
      action: onOpen == null
          ? null
          : DabblerBannerAction(
              label: l10n.notif_action_view,
              onPressed: onOpen,
            ),
    );
    return Semantics(
      liveRegion: true,
      button: onOpen != null,
      child: onOpen == null
          ? banner
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: banner,
            ),
    );
  }
}
