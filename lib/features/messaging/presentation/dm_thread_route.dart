import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/messaging/presentation/game_chat_route.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_access_state.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';

/// Path and name of the direct-message thread (KAN-556). Kept beside the game
/// chat route's constants (`game_chat_route.dart`), as that route does.
const String dmThreadRoutePath = '/messaging/thread/:conversationId';
const String dmThreadRouteName = 'messagingThread';
const String dmThreadRouteParam = 'conversationId';

/// The body of the DM thread route: the shared chat screen in its DM form
/// when the game chat route is enabled (same flags), otherwise the
/// unavailable state, fetching nothing.
Widget dmThreadRouteBody({
  required String conversationId,
  bool messaging = FeatureFlags.messaging,
  bool gameChat = FeatureFlags.enableMessagingGameChat,
}) => gameChatRouteEnabled(messaging: messaging, gameChat: gameChat)
    ? GameChatScreen.dm(conversationId: conversationId)
    : const GameChatAccessState(kind: GameChatAccessKind.unavailable);

/// The DM thread route. No redirect: a disabled deep link lands on the
/// unavailable state, as the game chat route does.
GoRoute dmThreadRoute({
  GlobalKey<NavigatorState>? parentNavigatorKey,
  bool messaging = FeatureFlags.messaging,
  bool gameChat = FeatureFlags.enableMessagingGameChat,
}) => GoRoute(
  parentNavigatorKey: parentNavigatorKey,
  path: dmThreadRoutePath,
  name: dmThreadRouteName,
  pageBuilder: (context, state) => FadeThroughTransitionPage(
    key: state.pageKey,
    child: dmThreadRouteBody(
      conversationId: state.pathParameters[dmThreadRouteParam] ?? '',
      messaging: messaging,
      gameChat: gameChat,
    ),
  ),
);
