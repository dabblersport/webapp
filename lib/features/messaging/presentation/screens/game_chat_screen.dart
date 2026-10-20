import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/messaging/presentation/controllers/game_chat_controller.dart';
import 'package:dabbler/features/messaging/domain/dm_failure.dart';
import 'package:dabbler/features/messaging/presentation/controllers/dm_chat_controller.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_realtime_providers.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/widgets/dm_reason_text.dart';
import 'package:dabbler/features/messaging/presentation/widgets/dm_thread_parts.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_access_state.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_reason_text.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_safety_sheets.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_thread_items.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/messaging/presentation/widgets/chat_composer_inset.dart';

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
/// KAN-556: [GameChatScreen.dm] is the same screen for a direct message: the
/// counterpart's header with an overflow (Mute/Unmute, Block user, Report
/// user), a direct-context thread without system lines, and the DM read-only
/// lines. The game chat path is unchanged.
class GameChatScreen extends ConsumerStatefulWidget {
  const GameChatScreen({super.key, required this.gameId, this.gameEndAt})
    : conversationId = null;

  /// The direct message [conversationId] (KAN-556).
  const GameChatScreen.dm({super.key, required String this.conversationId})
    : gameId = '',
      gameEndAt = null;

  final String gameId;

  /// Set for a direct message; null for a game chat.
  final String? conversationId;

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

class _GameChatScreenState extends ConsumerState<GameChatScreen>
    with WidgetsBindingObserver {
  String _draft = '';
  DabblerOlderMessagesState _older = DabblerOlderMessagesState.idle;
  Timer? _poll;
  GameChatController? _controllerRef;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final controller = ref.read(_provider.notifier);
    _controllerRef = controller;
    controller.setOpen(true);
    _startPoll(ref.read(gameChatEffectivePollProvider));
  }

  bool get _isDm => widget.conversationId != null;

  /// The game chat's controller, or the DM's (a [GameChatController] too).
  AsyncNotifierFamilyProvider<GameChatController, GameChatViewState, String>
  get _provider => _isDm
      ? dmChatControllerProvider(widget.conversationId!)
      : gameChatControllerProvider(widget.gameId);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controllerRef?.setOpen(false);
    _poll?.cancel();
    super.dispose();
  }

  /// One catch-up fetch when the app comes back to the foreground (KAN-544).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    ref.read(_provider.notifier).refreshNewest();
  }

  /// (Re)starts the poll at [interval]; null means no polling. The interval is
  /// the normal one until a Realtime channel is SUBSCRIBED, then the 60 s
  /// safety poll (see [gameChatEffectivePollProvider]).
  void _startPoll(Duration? interval) {
    _poll?.cancel();
    _poll = null;
    if (interval == null) return;
    _poll = Timer.periodic(interval, (_) {
      if (!mounted) return;
      ref.read(_provider.notifier).refreshNewest();
    });
  }

  Future<void> _loadOlder() async {
    setState(() => _older = DabblerOlderMessagesState.loading);
    final ok = await ref.read(_provider.notifier).loadOlder();
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
    ref.read(_provider.notifier).send(body);
  }

  void _retry(String clientKey) =>
      ref.read(_provider.notifier).retry(clientKey);

  void _reload() => ref.invalidate(_provider);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen<Duration?>(gameChatEffectivePollProvider, (_, next) {
      _startPoll(next);
    });
    final async = ref.watch(_provider);
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
          body = ChatStickToLatest(child: _thread(context, l10n, view));
          if (view.status == GameChatStatus.ready) {
            composer = _composer(l10n, view);
          } else if (view.dm?.readOnly != null) {
            composer = dmReadOnlyNotice(l10n, view.dm!.readOnly!);
          } else if (view.isClosedByGame) {
            composer = _closedNotice(l10n, view);
          } else if (view.reason == MessagingReason.leftReadOnly) {
            composer = _leftNotice(l10n);
          }
        case GameChatStatus.unavailable:
        case GameChatStatus.removed:
        // Handled above; unreachable here.
        case GameChatStatus.error:
          body = DabblerEmptyState.error(
            key: GameChatScreen.errorKey,
            // A typed reason shows its own line; anything else the generic one.
            title: view.dm?.capReached == true
                ? dmReasonText(l10n, DmCapReachedFailure())!
                : gameChatReasonText(
                        l10n,
                        view.reason ?? MessagingReason.unknown,
                      ) ??
                      l10n.messaging_chat_error,
            retryLabel: l10n.messaging_chat_offline_retry,
            onRetry: _reload,
          );
      }
    }
    final dm = view?.dm;
    if (_isDm && dm != null && view?.conversation != null) {
      return DabblerPage(
        topBar: dmThreadHeader(
          l10n: l10n,
          dm: dm,
          onBack: () => context.canPop() ? context.pop() : null,
          onOverflow: () => _openDmOptions(view!),
          onOpenProfile: dm.counterpartUserId == null
              ? null
              : () => context.push(
                  '${RoutePaths.userProfile}/${dm.counterpartUserId}',
                ),
        ),
        body: _muteFailed
            ? Column(
                children: [
                  DabblerInlineMessage(
                    l10n.messaging_dm_mute_failed,
                    key: DmThreadKeys.muteFailed,
                  ),
                  Expanded(child: body),
                ],
              )
            : body,
        bottomBar: composer == null ? null : ChatComposerInset(child: composer),
      );
    }
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: l10n.messaging_chat_title,
        backLabel: l10n.auth_back,
        onBack: () => context.canPop() ? context.pop() : null,
        actions: [if (view?.conversation != null) _muteAction(l10n, view!)],
      ),
      body: body,
      bottomBar: composer == null ? null : ChatComposerInset(child: composer),
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
      includeSystem: !_isDm,
    );
    return DabblerMessageThread(
      key: GameChatScreen.threadKey,
      context: _isDm
          ? DabblerMessageContext.direct
          : DabblerMessageContext.group,
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

  GameChatController get _controller => ref.read(_provider.notifier);

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
      onBlocked: _isDm ? _onBlocked : null,
    );
  }

  bool _muteFailed = false;

  void _onBlocked() {
    final c = _controller;
    if (c is DmChatController) c.markBlockedByMe();
  }

  /// The DM overflow menu (KAN-556).
  Future<void> _openDmOptions(GameChatViewState view) async {
    final dm = view.dm;
    if (dm == null) return;
    // Report user reports their latest message, through the same flow as a
    // message's own Report.
    final latest = view.items
        .map((i) => i.message)
        .whereType<Message>()
        .where((m) => m.senderUserId == dm.counterpartUserId)
        .lastOrNull;
    final action = await showDmThreadOptions(
      context,
      muted: view.isMuted,
      canBlock: dm.readOnly == null && dm.counterpartUserId != null,
      canReport: latest != null,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case DmThreadAction.toggleMute:
        setState(() => _muteFailed = false);
        final ok = await _controller.setMuted(!view.isMuted);
        if (mounted && !ok) setState(() => _muteFailed = true);
      case DmThreadAction.block:
        await showDabblerSheet<void>(
          context: context,
          detent: DabblerSheetDetent.content,
          title: AppLocalizations.of(context).messaging_block_title,
          builder: (_) => GameChatBlockSheet(
            targetUserId: dm.counterpartUserId!,
            onBlocked: _onBlocked,
          ),
        );
      case DmThreadAction.report:
        if (latest == null) return;
        await showGameChatReportSheet(
          context,
          onSubmit: (reason) => _controller.report(latest.id, reason),
        );
    }
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

  /// The member left the game: the existing left_read_only line takes the
  /// composer's place; earlier messages stay readable above it.
  Widget _leftNotice(AppLocalizations l10n) => DabblerChatComposer(
    key: GameChatScreen.closedNoticeKey,
    value: '',
    notice: DabblerComposerNotice(
      icon: 'lock',
      text: l10n.messaging_reason_left_read_only,
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
