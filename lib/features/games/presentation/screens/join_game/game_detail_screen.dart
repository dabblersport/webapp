import 'package:dabbler/features/bans/presentation/remove_with_ban_sheet.dart';
import 'package:dabbler/core/navigation/back_or_tab.dart';
import 'package:dabbler/features/attendance/presentation/check_in_bar.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show myProfileIdProvider;
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_entry.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_entry.dart';
import 'package:dabbler/core/system_ui/system_chrome_sync.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/features/games/presentation/controllers/join_action_toast.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_content.dart';
import 'package:dabbler/features/games/data/repositories/game_host_repository.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_host_actions.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_join_labels.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_series_widgets.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_entry.dart';
import 'package:dabbler/features/sports/presentation/join_gate.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Game details (D01), drawn from `Details.dc.html` "Game details".
///
/// The screen is a [DabblerDetailPage]: a sport-coloured [DabblerDetailHeader],
/// the headcount, the fact tiles, the host, the squad and the place, over a
/// [DabblerActionBar] that holds the cost and the one call to action. Same
/// provider, controller, routes, join / leave / request / remove flows and
/// deep-link behaviour as before; only the widget tree changed.
class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({
    super.key,
    required this.gameId,
    this.focusRequests = false,
    this.linkToken,
  });
  final String gameId;

  /// When true (join-request notification deep link), auto-scrolls to the
  /// squad section once the game has loaded.
  final bool focusRequests;

  /// KAN-939: the share URL's join token (`?lt=`), for the read and the join.
  final String? linkToken;

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _playersKey = GlobalKey();
  bool _didFocusScroll = false;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The controller is autoDispose.family but survives while an earlier
    // instance of this screen is in the nav stack (e.g. arriving again via a
    // notification tap). Reload so this entry never shows stale data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final ctrl = ref.read(
          gameViewControllerProvider(widget.gameId).notifier,
        );
        if (widget.linkToken != null) ctrl.linkToken = widget.linkToken;
        ctrl.refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Websockets are suspended in the background, so realtime events (host
    // approving a request, roster changes) are missed — resync on resume.
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(gameViewControllerProvider(widget.gameId).notifier).resync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String message, {required bool isError}) {
    showGameToast(
      DabblerToastProvider.maybeOf(context),
      message,
      isError: isError,
    );
  }

  Future<void> _shareGame(GameView game) async {
    final when = DateFormat('EEE, MMM d · h:mm a').format(game.startAt);
    final where = [
      game.venueName,
      game.areaName,
    ].whereType<String>().join(', ');
    final headline = [
      'Join me for ${game.title} on Dabbler!',
      when,
      if (where.isNotEmpty) where,
    ].join(' · ');
    // share_plus: uri and text are mutually exclusive — sharing the uri makes
    // the game link a first-class URL attachment (rich preview in messengers)
    // instead of plain text. The headline rides along as title/subject.
    final failed = AppLocalizations.of(context).game_share_link_failed;
    final ctrl = ref.read(gameViewControllerProvider(widget.gameId).notifier);
    final link = await buildGameShareLink(
      game: game,
      isHost: ctrl.isHost,
      repo: ref.read(gameHostRepositoryProvider),
      arrivedToken: widget.linkToken,
      sharerProfileId: ref.read(myProfileIdProvider).valueOrNull,
    );
    if (!mounted) return;
    link.fold(
      (_) => _toast(failed, isError: true),
      (url) => SharePlus.instance.share(
        ShareParams(uri: Uri.parse(url), title: headline, subject: headline),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameViewControllerProvider(widget.gameId));
    final ctrl = ref.read(gameViewControllerProvider(widget.gameId).notifier);

    ref.listen(gameViewControllerProvider(widget.gameId), (prev, next) {
      if (!mounted) return;
      if (next.lastAction != null && prev?.lastAction != next.lastAction) {
        _toast(joinActionMessage(next.lastAction!), isError: false);
      } else if (next.error != null && prev?.error != next.error) {
        _toast(next.error!, isError: true);
      }
    });

    if (state.isLoading && !state.hasGame) return _loading();
    if (!state.hasGame) return _error(state.error ?? 'Game not found');

    final game = state.game!;

    // Notification deep link: scroll to the squad section once the first full
    // load has settled.
    if (widget.focusRequests && !_didFocusScroll && !state.isLoading) {
      _didFocusScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _playersKey.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(
            ctx,
            duration: DabblerMotion.durationOf(
              context,
              DabblerMotion.heroCrossfade,
            ),
            curve: DabblerMotion.emphasizedDecelerate,
            alignment: 0.08,
          );
        }
      });
    }

    // Mobile browser (link opened without the native app): offer to
    // open/install the app. Native builds never show this.
    final showBanner =
        kIsWeb &&
        !_bannerDismissed &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    final where = gameWhereSection(game);
    return DabblerDetailPage(
      controller: _scroll,
      banner: showBanner ? _openInAppBanner(game.id) : null,
      header: SystemChromeSurface.detailHeader(
        child: DabblerDetailHeader(
          leading: DabblerOnColorIconButton(
            icon: 'arrow-circle-left',
            mirrorInRtl: true,
            semanticLabel: AppLocalizations.of(context).auth_back,
            onPressed: () => backOrTab(context),
          ),
          actions: [
            DabblerOnColorIconButton(
              icon: 'share',
              semanticLabel: AppLocalizations.of(context).sfx_share,
              onPressed: () => _shareGame(game),
            ),
          ],
          chips: [
            game.statusLabel,
            if (game.sportNameEn != null) game.sportNameEn!,
            if (game.variantNameEn != null) game.variantNameEn!,
            ?_skillChip(game),
          ],
          title: game.title,
          place: [
            game.venueName,
            game.areaName,
          ].whereType<String>().join(' · '),
        ),
      ),
      bottomBar: _actionBar(state, ctrl),
      children: [
        gameHeadcount(state),
        ?gameCheckInEntry(game, show: ctrl.isOnRoster && !ctrl.isHost),
        AttendanceListEntry(eventId: game.id, show: ctrl.isHost),
        gameLifecycleCard(game),
        PostActivityEntry(
          eventId: game.id,
          title: game.title,
          endAt: game.endAt,
        ),
        // KAN-516: the one flag-gated game-chat entry; absent while any
        // messaging flag is false.
        GameChatEntry(
          gameId: game.id,
          allowed: ctrl.isHost || ctrl.isOnRoster,
          gameEndAt: game.endAt,
        ),
        ?gameSeriesBadge(context, game),
        gameFactTiles(context, game),
        gameHostCard(context, game),
        if (ctrl.isHost && game.isSeries && !game.isCancelled)
          DabblerButton(
            key: const ValueKey<String>('game-series-cancel'),
            label: AppLocalizations.of(context).recurring_cancel_action,
            tone: DabblerButtonTone.destructive,
            size: DabblerButtonSize.full,
            fullWidth: true,
            onPressed: () => _openCancelSeries(game, ctrl),
          ),
        ?gameCancelEntry(
          context,
          game: game,
          isHost: ctrl.isHost,
          repo: ref.read(gameHostRepositoryProvider),
          onDone: ctrl.refresh,
          toast: (m, err) => _toast(m, isError: err),
        ),
        ...gameSquadSections(
          context,
          state: state,
          ctrl: ctrl,
          sectionKey: _playersKey,
          onRemove: (p) => _confirmRemove(ctrl, p),
        ),
        ?where,
      ],
    );
  }

  /// The skill tier as the header's last chip (`Details.dc.html:68`).
  String? _skillChip(GameView game) {
    final tier = gamesSkillTierFor(game.minSkill, game.maxSkill);
    return tier == null
        ? null
        : gamesSkillTierLabel(AppLocalizations.of(context), tier);
  }

  // ── Loading / error ──────────────────────────────────────────────────────

  Widget _loading() {
    return DabblerDetailPage(
      header: DabblerImage(
        height: DabblerSizing.heroCoverHeight,
        radius: BorderRadius.zero,
      ),
      children: const [
        DabblerSkeleton.rect(
          width: double.infinity,
          height: DabblerSizing.skeletonBlockHeight,
        ),
        Row(
          children: [
            Expanded(
              child: DabblerSkeleton.rect(
                height: DabblerSizing.skeletonBlockHeight,
              ),
            ),
            DabblerGap.h(DabblerSpacing.space3),
            Expanded(
              child: DabblerSkeleton.rect(
                height: DabblerSizing.skeletonBlockHeight,
              ),
            ),
          ],
        ),
        DabblerSkeleton.rect(
          width: double.infinity,
          height: DabblerSizing.skeletonBlockHeight,
        ),
      ],
    );
  }

  Widget _error(String message) {
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(onBack: () => backOrTab(context)),
      body: DabblerEmptyState.error(
        icon: 'warning-2',
        title: message,
        retryLabel: 'Go back',
        onRetry: () => backOrTab(context),
      ),
    );
  }

  // ── Mobile-web banner ────────────────────────────────────────────────────

  /// Deep-link into the installed app. Not part of the design frame;
  /// design-system defaults only. (The store listing's install button is not
  /// built while RoutePaths.appStoreUrl / playStoreUrl are empty — the banner
  /// carries one action.)
  Widget _openInAppBanner(String gameId) {
    return DabblerBanner(
      title: 'Dabbler is better in the app',
      icon: const DabblerIcon('flash'),
      onDismiss: () => setState(() => _bannerDismissed = true),
      action: DabblerBannerAction(
        label: 'Open app',
        // Custom scheme: opens the installed app straight on this game; the
        // browser shows its own "open in Dabbler?" prompt. No-op if missing.
        onPressed: () => launchUrl(
          Uri.parse(
            '${RoutePaths.deepLinkPrefix}/game/$gameId'
            '${widget.linkToken == null ? '' : '?lt=${widget.linkToken}'}',
          ),
          mode: LaunchMode.externalApplication,
        ),
      ),
    );
  }

  // ── Action bar ───────────────────────────────────────────────────────────

  Widget _actionBar(GameViewState state, GameViewController ctrl) {
    final game = state.game!;
    final isHost = ctrl.isHost;
    final isCancelled = game.isCancelled;
    final isEnded = game.endAt.isBefore(DateTime.now());

    final DabblerButton cta;
    if (isHost && !isCancelled && !isEnded) {
      cta = DabblerButton(
        label: AppLocalizations.of(context).game_edit,
        icon: 'edit',
        tone: DabblerButtonTone.outlined,
        size: DabblerButtonSize.full,
        fullWidth: true,
        onPressed: () => _openEditGame(game.id, ctrl),
      );
    } else if (isCancelled || isEnded) {
      cta = DabblerButton(
        label: isCancelled ? 'Cancelled' : 'Ended',
        icon: 'slash',
        tone: DabblerButtonTone.neutral,
        size: DabblerButtonSize.full,
        fullWidth: true,
        disabled: true,
      );
    } else if (ctrl.isOnRoster) {
      final l = AppLocalizations.of(context);
      final ci = checkInBarActions(
        context,
        ref,
        eventId: game.id,
        leaveLabel: state.isActing ? l.game_leaving : l.game_leave,
        onLeave: state.isActing ? null : _confirmLeave,
      );
      if (ci != null) {
        return DabblerActionBar(
          price: gameEntryLabel(game),
          secondary: ci.secondary,
          primary: ci.primary,
        );
      }
      cta = DabblerButton(
        label: state.isActing ? l.game_leaving : l.game_leave,
        icon: 'logout',
        tone: DabblerButtonTone.outlined,
        size: DabblerButtonSize.full,
        fullWidth: true,
        disabled: state.isActing,
        onPressed: _confirmLeave,
      );
    } else if (ctrl.isOnWaitlist) {
      cta = DabblerButton(
        label: AppLocalizations.of(context).listing_on_waitlist,
        icon: 'clock',
        tone: DabblerButtonTone.neutral,
        size: DabblerButtonSize.full,
        fullWidth: true,
        disabled: true,
      );
    } else if (state.hasPendingRequest) {
      cta = DabblerButton(
        label: state.isActing ? 'Cancelling…' : 'Cancel request',
        icon: 'close-square',
        tone: DabblerButtonTone.destructive,
        size: DabblerButtonSize.full,
        fullWidth: true,
        disabled: state.isActing,
        onPressed: ctrl.cancelJoinRequest,
      );
    } else {
      cta = DabblerButton(
        label: state.isActing
            ? gameJoiningLabel(game.joinPolicy)
            : gameJoinLabel(game),
        icon: state.isActing ? null : gameJoinIcon(game.joinPolicy),
        size: DabblerButtonSize.full,
        fullWidth: true,
        loading: state.isActing,
        onPressed: () => _join(ctrl),
      );
    }
    return DabblerActionBar(price: gameEntryLabel(game), primary: cta);
  }

  /// KAN-1060: a join first makes sure the sport is in My sports.
  Future<void> _join(GameViewController ctrl) async {
    final game = ref.read(gameViewControllerProvider(widget.gameId)).game;
    final bool go = await confirmSportForJoin(
      context: context,
      ref: ref,
      sportId: game?.sportId,
      sportKey: game?.sportKey,
      sportName: game?.sportNameEn,
    );
    if (go && mounted) await ctrl.joinGame();
  }

  Future<void> _openEditGame(String gameId, GameViewController ctrl) async {
    final game = ref.read(gameViewControllerProvider(widget.gameId)).game;
    if (game != null && game.isSeries) {
      final scope = await showSeriesEditScopeSheet(
        context,
        gameStart: game.startAt,
      );
      if (scope == null || !mounted) return;
      if (scope == SeriesEditScope.allFuture) {
        final changed = await showSeriesFutureEditSheet(context, game: game);
        if (changed == true) await ctrl.refresh();
        return;
      }
    }
    if (!mounted) return;
    final updated = await showGameComposerSheet(context, editGameId: gameId);
    if (updated == true) await ctrl.refresh();
  }

  Future<void> _openCancelSeries(GameView game, GameViewController ctrl) async {
    final seriesId = game.seriesId;
    if (seriesId == null) return;
    final cancelled = await showSeriesCancelSheet(context, seriesId: seriesId);
    if (cancelled == true) await ctrl.refresh();
  }

  Future<void> _confirmLeave() async {
    if (await confirmLeaveGame(context) && mounted) {
      ref.read(gameViewControllerProvider(widget.gameId).notifier).leaveGame();
    }
  }

  Future<void> _confirmRemove(
    GameViewController ctrl,
    GameRosterEntry player,
  ) async {
    final choice = await showRemoveWithBanSheet(
      context: context,
      name: player.displayName,
      description: AppLocalizations.of(context).ban_remove_game_body,
      isSeries:
          ref.read(gameViewControllerProvider(widget.gameId)).game?.seriesId !=
          null,
    );
    if (choice == null) return;
    await ctrl.removePlayer(
      player.profileId,
      banScope: choice.scope,
      reason: choice.reason,
    );
  }
}
