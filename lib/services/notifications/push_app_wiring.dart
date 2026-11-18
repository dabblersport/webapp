// KAN-992 (W1-F6): the push section's app glue, called once from main.dart —
// the open chat from the router, the app-icon badge from the server count,
// notification actions, and the target-state sheet for a tapped push whose
// target is gone.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_target_states.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';

import 'push_action_runner.dart';
import 'push_contract.dart';
import 'push_notification_service_mobile.dart' as push_mobile;
import 'push_presence.dart';

/// Wires the push layer to the app (mobile; on web only the open chat and
/// badge rules apply, both no-ops off iOS).
void wirePushToApp({
  required ProviderContainer container,
  required GoRouter router,
  required void Function(String route) openRoute,
}) {
  final presence = PushPresence.instance;

  // The chat open on screen (no alert for its messages).
  void syncChat() {
    // The top of the stack, a pushed chat included.
    final config = router.routerDelegate.currentConfiguration;
    final location = config.isEmpty ? '/' : config.last.matchedLocation;
    presence.setOpenChat(OpenChat.fromLocation(location));
  }

  router.routerDelegate.addListener(syncChat);

  // The app-icon badge equals the server's unread count; 0 clears it.
  container.listen<int>(
    unreadNotificationCountProvider,
    (_, next) => presence.setBadge(next),
    fireImmediately: true,
  );

  BuildContext? navContext() =>
      router.routerDelegate.navigatorKey.currentContext;

  // A tapped push whose target is gone: the Center opens with its sheet.
  push_mobile.PushNotificationService.instance.onTargetUnavailable = (state) {
    openRoute(RoutePaths.notifications);
    Future<void>.delayed(DabblerMotion.delaySettle, () {
      final ctx = navContext();
      if (ctx != null && ctx.mounted) showNotifTargetSheet(ctx, state);
    });
  };

  final runner = PushActionRunner.supabase(
    reply: (conversationId, text) async {
      final result = await container
          .read(messagingRepositoryProvider)
          .sendTextMessage(
            conversationId: conversationId,
            body: text,
            idempotencyKey: const Uuid().v4(),
          );
      result.fold((f) => throw StateError(f.message), (_) {});
    },
    confirmCancelPlace: (_) async {
      // KAN-1016: from a killed app the action arrives before the first
      // frame; wait for the navigator as the tap route does.
      var ctx = navContext();
      for (var i = 0; i < 20 && (ctx == null || !ctx.mounted); i++) {
        await Future<void>.delayed(DabblerMotion.delaySettle);
        ctx = navContext();
      }
      if (ctx == null || !ctx.mounted) return false;
      return await _confirmCancelPlace(ctx) ?? false;
    },
    openRoute: openRoute,
  );
  presence.actions.listen((event) async {
    final outcome = await runner.run(event);
    debugPrint('Push action ${event.action.wire}: ${outcome.name}');
  });
}

/// G-14: "Give up your place? No penalty."
Future<bool?> _confirmCancelPlace(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showAppSheet<bool>(
    context: context,
    title: l.notif_push_cancel_place_title,
    detent: DabblerSheetDetent.content,
    builder: (sheet) => DabblerSheetBody(
      spacing: DabblerSpacing.space3,
      children: <Widget>[
        DabblerText(
          l.notif_push_cancel_place_hint,
          style: DabblerType.body,
          tone: DabblerTextTone.secondary,
        ),
        DabblerButton(
          label: l.notif_push_cancel_place_confirm,
          fullWidth: true,
          onPressed: () => Navigator.of(sheet).pop(true),
        ),
        DabblerButton(
          label: l.notif_push_keep_place,
          tone: DabblerButtonTone.neutral,
          fullWidth: true,
          onPressed: () => Navigator.of(sheet).pop(false),
        ),
      ],
    ),
  );
}
