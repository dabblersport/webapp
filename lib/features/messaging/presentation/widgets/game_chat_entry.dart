import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/messaging/presentation/game_chat_route.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The three messaging flags the game-chat entry reads. Defaults to the real
/// compile-time flags (all false); a test overrides the provider instead of
/// flipping a const.
typedef GameChatEntryFlags = ({bool messaging, bool gameChat, bool reporting});

final gameChatEntryFlagsProvider = Provider<GameChatEntryFlags>(
  (ref) => (
    messaging: FeatureFlags.messaging,
    gameChat: FeatureFlags.enableMessagingGameChat,
    reporting: FeatureFlags.enableMessagingReporting,
  ),
);

/// Whether the entry is drawn: every flag on, the flags consistent, and the
/// user allowed (host or on the roster of the game).
bool gameChatEntryVisible(GameChatEntryFlags flags, {required bool allowed}) =>
    allowed &&
    flags.messaging &&
    flags.gameChat &&
    flags.reporting &&
    FeatureFlags.messagingFlagsConsistent(
      flags.messaging,
      flags.gameChat,
      flags.reporting,
    );

/// The one entry to the game chat (KAN-516), placed on the game details
/// screen. With the committed flags it draws nothing.
class GameChatEntry extends ConsumerWidget {
  const GameChatEntry({
    super.key,
    required this.gameId,
    required this.allowed,
    this.gameEndAt,
  });

  final String gameId;

  /// The user is the host or on the roster.
  final bool allowed;

  /// Passed to the chat so it can draw the "game finished" line.
  final DateTime? gameEndAt;

  static const buttonKey = ValueKey<String>('messaging-game-chat-entry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(gameChatEntryFlagsProvider);
    if (!gameChatEntryVisible(flags, allowed: allowed)) {
      return const SizedBox.shrink();
    }
    return DabblerButton(
      key: buttonKey,
      label: AppLocalizations.of(context).messaging_chat_open,
      icon: 'messages-2',
      tone: DabblerButtonTone.outlined,
      size: DabblerButtonSize.full,
      fullWidth: true,
      onPressed: () => context.pushNamed(
        gameChatRouteName,
        pathParameters: {'gameId': gameId},
        extra: gameEndAt,
      ),
    );
  }
}
