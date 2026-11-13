import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/messaging/presentation/game_chat_route.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_access_state.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';

/// Path of the meetup chat (KAN-928), next to the meetup detail route.
const String meetupChatRoutePath = '/meetups/:meetupId/chat';
const String meetupChatRouteName = 'messagingMeetupChat';

/// The meetup chat at [meetupId], for a `context.push`.
String meetupChatLocation(String meetupId) =>
    '/meetups/${Uri.encodeComponent(meetupId)}/chat';

/// The body of the meetup chat route: gated like the game chat; a disabled
/// deep link shows the unavailable state and fetches nothing.
Widget meetupChatRouteBody({
  required String meetupId,
  String? title,
  bool messaging = FeatureFlags.messaging,
  bool gameChat = FeatureFlags.enableMessagingGameChat,
}) => gameChatRouteEnabled(messaging: messaging, gameChat: gameChat)
    ? GameChatScreen.meetup(meetupId: meetupId, title: title)
    : const GameChatAccessState(kind: GameChatAccessKind.unavailable);

/// The meetup chat route; `extra` may carry the meetup's title. No
/// redirect: who may read is the Worker's answer.
GoRoute meetupChatRoute({
  GlobalKey<NavigatorState>? parentNavigatorKey,
  bool messaging = FeatureFlags.messaging,
  bool gameChat = FeatureFlags.enableMessagingGameChat,
}) => GoRoute(
  parentNavigatorKey: parentNavigatorKey,
  path: meetupChatRoutePath,
  name: meetupChatRouteName,
  pageBuilder: (context, state) => FadeThroughTransitionPage(
    key: state.pageKey,
    child: meetupChatRouteBody(
      meetupId: state.pathParameters['meetupId'] ?? '',
      title: state.extra is String ? state.extra as String : null,
      messaging: messaging,
      gameChat: gameChat,
    ),
  ),
);
