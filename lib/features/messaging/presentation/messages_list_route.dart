import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/messaging/presentation/dm_thread_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/messages_list_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_access_state.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';

/// Path and name of the Messages list (KAN-549). Kept beside the game chat
/// route's constants (`game_chat_route.dart`), as that route does.
const String messagesListRoutePath = '/messaging';
const String messagesListRouteName = 'messagingList';

/// The route a DM row opens: the DM thread (KAN-556), with the conversation
/// id as its path parameter.
const String messagesListDmRouteName = dmThreadRouteName;

/// The path parameter the DM row fills with the conversation id.
const String messagesListDmRouteParam = dmThreadRouteParam;

/// The route body: the list when both flags are on, otherwise the same
/// unavailable state the game chat route shows (KAN-518). Fetches nothing
/// when disabled.
class MessagesListRouteBody extends ConsumerWidget {
  const MessagesListRouteBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      messagesListEnabled(ref.watch(messagesListFlagsProvider))
      ? const MessagesListScreen()
      : const GameChatAccessState(kind: GameChatAccessKind.unavailable);
}

/// The Messages list route. No redirect: a disabled deep link lands on the
/// unavailable state.
GoRoute messagesListRoute({GlobalKey<NavigatorState>? parentNavigatorKey}) =>
    GoRoute(
      parentNavigatorKey: parentNavigatorKey,
      path: messagesListRoutePath,
      name: messagesListRouteName,
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const MessagesListRouteBody(),
      ),
    );
