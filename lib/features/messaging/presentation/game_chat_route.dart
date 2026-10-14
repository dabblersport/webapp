import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';

/// Path of the game chat skeleton route (KAN-507). Kept here because
/// `route_constants.dart` is outside this ticket.
const String gameChatRoutePath = '/messaging/game/:gameId';
const String gameChatRouteName = 'messagingGameChat';

/// Whether the game chat route is enabled: the master `messaging` kill switch
/// AND `enableMessagingGameChat`. The reporting invariant is a flag-file
/// concern, not a router one.
bool gameChatRouteEnabled({
  bool messaging = FeatureFlags.messaging,
  bool gameChat = FeatureFlags.enableMessagingGameChat,
}) => messaging && gameChat;

/// The redirect of the game chat route: when disabled it does exactly what the
/// existing disabled messaging routes do (`socialMessagesRoute`,
/// `socialChatConversationIdRoute`: redirect to home); otherwise none.
String? gameChatRedirect({
  bool messaging = FeatureFlags.messaging,
  bool gameChat = FeatureFlags.enableMessagingGameChat,
}) => gameChatRouteEnabled(messaging: messaging, gameChat: gameChat)
    ? null
    : RoutePaths.home;

/// The game chat route. Its body is the game chat screen (KAN-516, T16a);
/// `extra` may carry the game's `end_at`.
GoRoute gameChatRoute({GlobalKey<NavigatorState>? parentNavigatorKey}) =>
    GoRoute(
      parentNavigatorKey: parentNavigatorKey,
      path: gameChatRoutePath,
      name: gameChatRouteName,
      redirect: (context, state) => gameChatRedirect(),
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: GameChatScreen(
          gameId: state.pathParameters['gameId'] ?? '',
          gameEndAt: state.extra is DateTime ? state.extra as DateTime : null,
        ),
      ),
    );

/// Empty placeholder body (KAN-507): no copy, identified by key only. No longer
/// the route body; kept for its existing tests.
class GameChatPlaceholder extends StatelessWidget {
  const GameChatPlaceholder({super.key});

  static const placeholderKey = ValueKey<String>(
    'messaging-game-chat-placeholder',
  );

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: placeholderKey);
}
