import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/messaging/presentation/controllers/game_chat_controller.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_access_state.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_safety_sheets.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_thread_items.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The game chat thread and composer (KAN-516, T16a).
///
/// States: loading (skeleton), empty, populated, sending, failed (Retry
/// resends with the same idempotency key), offline. Polling refresh only.
/// Part b (KAN-517, T16b): when the repository reports game_ended or
/// game_cancelled the composer is replaced by the DS composer notice (reads
/// still work); conversation-level mute/unmute in the top bar (no Leave, D6);
/// another member's message opens Report and Block sheets. The
/// Part c (KAN-518, T16c): typed reason not_in_pilot shows the unavailable
/// state and removed the removed state ([GameChatAccessState]).
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
  static const closedNoticeKey = ValueKey<String>('messaging-chat-closed');

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
    // T6 (KAN-518): unavailable and removed replace the whole screen, thread,
    // composer and title included; nothing about the conversation shows.
    if (view?.status == GameChatStatus.unavailable) {
      return const GameChatAccessState(kind: GameChatAccessKind.unavailable);
    }
    if (view?.status == GameChatStatus.removed) {
      return const GameChatAccessState(kind: GameChatAccessKind.removed);
    }
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
          } else if (view.isClosedByGame) {
            composer = _closedNotice(l10n, view);
          }
        case GameChatStatus.unavailable:
        case GameChatStatus.removed:
        // Handled above; unreachable here.
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
        actions: [if (view?.conversation != null) _muteAction(l10n, view!)],
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
      onMessagePress: (m) => _openOptions(view, m),
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

  GameChatController get _controller =>
      ref.read(gameChatControllerProvider(widget.gameId).notifier);

  DabblerNavigationAction _muteAction(
    AppLocalizations l10n,
    GameChatViewState view,
  ) {
    final muted = view.isMuted;
    return DabblerNavigationAction(
      icon: muted ? 'volume-slash' : 'volume-high',
      label: muted ? l10n.messaging_chat_unmute : l10n.messaging_chat_mute,
      loading: _muting,
      onPressed: _muting ? null : () => _toggleMute(!muted),
    );
  }

  bool _muting = false;

  Future<void> _toggleMute(bool muted) async {
    setState(() => _muting = true);
    await _controller.setMuted(muted);
    if (mounted) setState(() => _muting = false);
  }

  /// Another member's text message opens Report and Block. Own messages,
  /// pending sends and system lines open nothing.
  void _openOptions(GameChatViewState view, DabblerThreadMessage m) {
    if (m.direction != DabblerMessageDirection.incoming || m.id == null) {
      return;
    }
    final item = view.items.where((i) => i.message?.id == m.id).firstOrNull;
    final message = item?.message;
    final sender = message?.senderUserId;
    if (message == null || sender == null) return;
    showGameChatMessageOptions(
      context,
      senderUserId: sender,
      onReport: (reason) => _controller.report(message.id, reason),
    );
  }

  /// The DS composer notice that replaces the input row once the game ended
  /// or was cancelled (typed reason from the repository).
  Widget _closedNotice(AppLocalizations l10n, GameChatViewState view) =>
      DabblerChatComposer(
        key: GameChatScreen.closedNoticeKey,
        value: '',
        notice: DabblerComposerNotice(
          icon: 'lock',
          text: view.reason == MessagingReason.gameCancelled
              ? l10n.messaging_chat_closed_cancelled
              : l10n.messaging_chat_closed_ended,
        ),
      );

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
