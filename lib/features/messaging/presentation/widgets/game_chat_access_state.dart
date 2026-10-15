import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Which terminal access state the game chat shows (KAN-518, T16c).
enum GameChatAccessKind {
  /// D19: the user is not in the messaging pilot (typed reason
  /// `not_in_pilot`), or the chat route is disabled.
  unavailable,

  /// D7: the user is no longer an active member (typed reason `removed`).
  /// The copy says nothing about why or by whom.
  removed,
}

/// The unavailable / removed state of the game chat, per the T6 specs
/// (`02-unavailable-state.md`, `03-removed-state.md`): a back-only top bar with
/// no title, and a page-size DS empty state with one icon, ONE neutral line and
/// ONE secondary action back. It shows nothing about the conversation.
class GameChatAccessState extends StatelessWidget {
  const GameChatAccessState({super.key, required this.kind});

  final GameChatAccessKind kind;

  static const unavailableKey = ValueKey<String>('messaging-chat-unavailable');
  static const removedKey = ValueKey<String>('messaging-chat-removed');
  static const actionKey = ValueKey<String>('messaging-chat-access-action');

  /// The DS glyph for [kind] (spec: `info-circle` / `lock`).
  static String iconFor(GameChatAccessKind kind) => switch (kind) {
    GameChatAccessKind.unavailable => 'info-circle',
    GameChatAccessKind.removed => 'lock',
  };

  /// Pops to where the chat was opened from, or goes home with no history.
  static void goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (line, action) = switch (kind) {
      GameChatAccessKind.unavailable => (
        l10n.messaging_chat_unavailable_line,
        l10n.messaging_chat_unavailable_action,
      ),
      GameChatAccessKind.removed => (
        l10n.messaging_chat_removed_line,
        l10n.messaging_chat_removed_action,
      ),
    };
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        backLabel: l10n.auth_back,
        onBack: () => goBack(context),
      ),
      body: GameChatAccessBody(
        key: kind == GameChatAccessKind.unavailable
            ? unavailableKey
            : removedKey,
        icon: iconFor(kind),
        line: line,
        action: action,
        onAction: () => goBack(context),
      ),
    );
  }
}

/// The body alone, so the chat screen can swap a live thread for it.
class GameChatAccessBody extends StatelessWidget {
  const GameChatAccessBody({
    super.key,
    required this.icon,
    required this.line,
    required this.action,
    required this.onAction,
  });

  final String icon;
  final String line;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: Center(
      child: SingleChildScrollView(
        child: DabblerEmptyState(
          size: DabblerEmptyStateSize.page,
          icon: icon,
          title: line,
          action: DabblerButton(
            key: GameChatAccessState.actionKey,
            label: action,
            tone: DabblerButtonTone.secondary,
            onPressed: onAction,
          ),
        ),
      ),
    ),
  );
}
