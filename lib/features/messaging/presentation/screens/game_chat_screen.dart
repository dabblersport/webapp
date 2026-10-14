import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_thread_items.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The game chat thread and composer (KAN-516, T16a).
///
/// States: loading (skeleton), empty, populated, sending, failed (Retry
/// resends with the same idempotency key), offline. Polling refresh only.
/// Closed/read-only banners, mute, report and block are part b; the
/// unavailable/removed handling is part c (the route redirect is unchanged).
class GameChatScreen extends ConsumerStatefulWidget {
  const GameChatScreen({super.key, required this.gameId, this.gameEndAt});

  final String gameId;

  /// The game's `end_at`; when it has passed, the thread draws a
  /// "game finished" line.
  final DateTime? gameEndAt;

  static const threadKey = ValueKey<String>('messaging-chat-thread');
  static const composerKey = ValueKey<String>('messaging-chat-composer');
  static const loadingKey = ValueKey<String>('messaging-chat-loading');
  static const emptyKey = ValueKey<String>('messaging-chat-empty');
  static const offlineKey = ValueKey<String>('messaging-chat-offline');
  static const errorKey = ValueKey<String>('messaging-chat-error');
  static const pagerKey = ValueKey<String>('messaging-chat-older-pager');

  @override
  ConsumerState<GameChatScreen> createState() => _GameChatScreenState();
}

class _GameChatScreenState extends ConsumerState<GameChatScreen> {
  String _draft = '';
  DabblerOlderMessagesState _older = DabblerOlderMessagesState.idle;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    final interval = ref.read(gameChatPollIntervalProvider);
    if (interval != null) {
      _poll = Timer.periodic(interval, (_) {
        if (!mounted) return;
        ref
            .read(gameChatControllerProvider(widget.gameId).notifier)
            .refreshNewest();
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadOlder() async {
    setState(() => _older = DabblerOlderMessagesState.loading);
    final ok = await ref
        .read(gameChatControllerProvider(widget.gameId).notifier)
        .loadOlder();
    if (!mounted) return;
    setState(
      () => _older = ok
          ? DabblerOlderMessagesState.idle
          : DabblerOlderMessagesState.error,
    );
  }

  void _send() {
    final body = _draft.trim();
    if (body.isEmpty) return;
    setState(() => _draft = '');
    ref.read(gameChatControllerProvider(widget.gameId).notifier).send(body);
  }

  void _retry(String clientKey) => ref
      .read(gameChatControllerProvider(widget.gameId).notifier)
      .retry(clientKey);

  void _reload() => ref.invalidate(gameChatControllerProvider(widget.gameId));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(gameChatControllerProvider(widget.gameId));
    final view = async.valueOrNull;
    final Widget body;
    Widget? composer;
    if (view == null) {
      body = DabblerThreadSkeleton(
        key: GameChatScreen.loadingKey,
        semanticLabel: l10n.messaging_chat_loading,
      );
    } else {
      switch (view.status) {
        case GameChatStatus.offline:
          body = Column(
            key: GameChatScreen.offlineKey,
            children: [
              DabblerConnectionNotice(text: l10n.messaging_chat_offline),
              Expanded(
                child: DabblerEmptyState.error(
                  icon: 'wifi',
                  title: l10n.messaging_chat_offline,
                  retryLabel: l10n.messaging_chat_offline_retry,
                  onRetry: _reload,
                ),
              ),
            ],
          );
        case GameChatStatus.empty:
          body = Center(
            child: SingleChildScrollView(
              child: DabblerEmptyState(
                key: GameChatScreen.emptyKey,
                icon: 'messages-2',
                title: l10n.messaging_chat_empty_title,
                text: l10n.messaging_chat_empty_body,
                size: DabblerEmptyStateSize.page,
              ),
            ),
          );
          composer = _composer(l10n, view);
        case GameChatStatus.ready:
        case GameChatStatus.readOnly:
          body = _thread(context, l10n, view);
          if (view.status == GameChatStatus.ready) {
            composer = _composer(l10n, view);
          }
        case GameChatStatus.unavailable:
        case GameChatStatus.removed:
        case GameChatStatus.error:
          body = DabblerEmptyState.error(
            key: GameChatScreen.errorKey,
            title: l10n.messaging_chat_error,
            retryLabel: l10n.messaging_chat_offline_retry,
            onRetry: _reload,
          );
      }
    }
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: l10n.messaging_chat_title,
        backLabel: l10n.auth_back,
        onBack: () => context.canPop() ? context.pop() : null,
      ),
      body: body,
      bottomBar: composer,
    );
  }

  Widget _thread(
    BuildContext context,
    AppLocalizations l10n,
    GameChatViewState view,
  ) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final items = gameChatThreadItems(
      items: view.items,
      l10n: l10n,
      locale: locale,
      now: ref.watch(messagingClockProvider)(),
      gameEndAt: widget.gameEndAt,
      onRetry: _retry,
    );
    return DabblerMessageThread(
      key: GameChatScreen.threadKey,
      context: DabblerMessageContext.group,
      items: items,
      header: view.hasOlder
          ? DabblerOlderMessagesPager(
              key: GameChatScreen.pagerKey,
              state: _older,
              idleLabel: l10n.messaging_chat_older_load,
              loadingLabel: l10n.messaging_chat_older_loading,
              errorText: l10n.messaging_chat_older_error,
              retryLabel: l10n.messaging_chat_retry,
              onLoad: _loadOlder,
              onRetry: _loadOlder,
            )
          : null,
    );
  }

  Widget _composer(AppLocalizations l10n, GameChatViewState view) =>
      DabblerChatComposer(
        key: GameChatScreen.composerKey,
        value: _draft,
        placeholder: l10n.messaging_chat_composer_hint,
        sendLabel: l10n.messaging_chat_send,
        state: view.isSending
            ? DabblerChatComposerState.sending
            : DabblerChatComposerState.normal,
        onChange: (v) => setState(() => _draft = v),
        onSend: _send,
      );
}
