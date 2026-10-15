import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/presentation/game_chat_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The Messages list (KAN-549): the user's game chats, newest activity first,
/// each opening the existing game chat. Built from DS parts only.
///
/// A row shows the game name, a sport mark, the game's date and time, the
/// relative last-activity time and the state as a quiet label. It shows NO
/// unread count, preview or sender name. States: loading (skeleton rows),
/// empty, error with Retry, populated. No Realtime: loads on open and Retry.
class MessagesListScreen extends ConsumerWidget {
  const MessagesListScreen({super.key});

  static const listKey = ValueKey<String>('messages-list');
  static const loadingKey = ValueKey<String>('messages-list-loading');
  static const emptyKey = ValueKey<String>('messages-list-empty');
  static const errorKey = ValueKey<String>('messages-list-error');

  static ValueKey<String> rowKey(String gameId) =>
      ValueKey<String>('messages-list-row-$gameId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(messagesListProvider);
    final result = async.valueOrNull;
    final Widget body;
    if (result == null || async.isLoading) {
      body = _MessagesListSkeleton(
        key: loadingKey,
        semanticLabel: l10n.messaging_list_loading,
      );
    } else if (result is Ok<List<MyConversation>, Object>) {
      final chats = result.requireValue;
      body = chats.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: DabblerEmptyState(
                  key: emptyKey,
                  icon: 'messages',
                  title: l10n.messaging_list_empty_title,
                  text: l10n.messaging_list_empty_body,
                  size: DabblerEmptyStateSize.page,
                ),
              ),
            )
          : _list(context, ref, l10n, chats);
    } else {
      body = Center(
        child: SingleChildScrollView(
          child: DabblerEmptyState.error(
            key: errorKey,
            title: l10n.messaging_list_error_title,
            text: l10n.messaging_list_error_body,
            retryLabel: l10n.messaging_list_error_retry,
            onRetry: () => ref.invalidate(messagesListProvider),
          ),
        ),
      );
    }
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: l10n.messaging_list_title,
        backLabel: l10n.auth_back,
        onBack: () => context.canPop() ? context.pop() : null,
      ),
      body: body,
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<MyConversation> chats,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final now = ref.watch(messagingClockProvider)();
    return ListView.builder(
      key: listKey,
      itemCount: chats.length,
      itemBuilder: (context, i) {
        final c = chats[i];
        return DabblerConversationRow(
          key: rowKey(c.gameId),
          kind: DabblerConversationKind.game,
          sport: messagesListSport(c.sport),
          seed: c.gameId,
          title: messagesListTitle(l10n, c),
          timestamp: messagesListRelative(c.lastActivityAt, now, locale),
          kindLabel: messagesListGameTime(c.startAt, locale),
          state: DabblerConversationState(
            label: messagesListStateLabel(l10n, c.state),
          ),
          divider: i < chats.length - 1,
          onTap: () => context.pushNamed(
            gameChatRouteName,
            pathParameters: {'gameId': c.gameId},
            extra: c.endAt,
          ),
        );
      },
    );
  }
}

/// The DS sport for the RPC's sport name (`sports.name_en`, e.g.
/// `Table Tennis`); null when the system has no such sport.
DabblerSport? messagesListSport(String? name) {
  if (name == null) return null;
  final key = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  return key.isEmpty ? null : DabblerSport.fromKey(key);
}

/// The row title: the game's title, else one built from the sport name, else
/// the unknown-sport fallback.
String messagesListTitle(AppLocalizations l10n, MyConversation c) {
  final title = c.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  final sport = c.sport?.trim();
  if (sport != null && sport.isNotEmpty) {
    return l10n.messaging_list_fallback_title(sport);
  }
  return l10n.messaging_list_fallback_unknown_sport;
}

String messagesListStateLabel(
  AppLocalizations l10n,
  MyConversationState state,
) => switch (state) {
  MyConversationState.send => l10n.messaging_list_state_send,
  MyConversationState.readOnly => l10n.messaging_list_state_read_only,
  MyConversationState.left => l10n.messaging_list_state_left,
};

/// The game's local date and time, e.g. `Thu, Oct 16 7:30 PM`; empty when
/// unknown.
String? messagesListGameTime(DateTime? start, String locale) => start == null
    ? null
    : DateFormat.MMMEd(locale).add_jm().format(start.toLocal());

bool _arRegistered = false;

/// The relative last-activity time (`5 minutes ago`), localized; empty when
/// unknown.
String messagesListRelative(DateTime? at, DateTime now, String locale) {
  if (at == null) return '';
  if (!_arRegistered) {
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _arRegistered = true;
  }
  return timeago.format(at, locale: locale == 'ar' ? 'ar' : 'en', clock: now);
}

/// Skeleton rows shaped like conversation rows: a DS circle for the avatar
/// and DS text bars, with directional insets so it mirrors in RTL.
class _MessagesListSkeleton extends StatelessWidget {
  const _MessagesListSkeleton({super.key, required this.semanticLabel});

  final String semanticLabel;

  static const int _rows = 6;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < _rows; i++)
            const Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: DabblerConversationRow.paddingInline,
                vertical: DabblerConversationRow.paddingBlock,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DabblerSkeleton.circle(
                    width: DabblerConversationRow.avatarSize,
                  ),
                  SizedBox(width: DabblerSpacing.space4),
                  Expanded(child: DabblerSkeleton.text(lines: 3)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
