import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_content.dart';
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
  });
  final String gameId;

  /// When true (join-request notification deep link), auto-scrolls to the
  /// squad section once the game has loaded.
  final bool focusRequests;

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
        ref.read(gameViewControllerProvider(widget.gameId).notifier).refresh();
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
    DabblerToastProvider.maybeOf(context)?.show(
      DabblerToastSpec(
        message: message,
        tone: isError ? DabblerToastTone.error : DabblerToastTone.success,
      ),
    );
  }

  void _shareGame(GameView game) {
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
    SharePlus.instance.share(
      ShareParams(
        uri: Uri.parse(RoutePaths.gameLink(game.id)),
        title: headline,
        subject: headline,
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
        _toast(_actionMessage(next.lastAction!), isError: false);
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
      header: DabblerDetailHeader(
        leading: DabblerOnColorIconButton(
          icon: 'arrow-circle-left',
          mirrorInRtl: true,
          semanticLabel: 'Back',
          onPressed: () => context.pop(),
        ),
        actions: [
          DabblerOnColorIconButton(
            icon: 'share',
            semanticLabel: 'Share',
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
        place: [game.venueName, game.areaName].whereType<String>().join(' · '),
      ),
      bottomBar: _actionBar(state, ctrl),
      children: [
        gameHeadcount(state),
        gameFactTiles(context, game),
        gameHostCard(context, game),
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
      topBar: DabblerNavigationTopBar.titled(onBack: () => context.pop()),
      body: DabblerEmptyState.error(
        icon: 'warning-2',
        title: message,
        retryLabel: 'Go back',
        onRetry: () => context.pop(),
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
          Uri.parse('${RoutePaths.deepLinkPrefix}/game/$gameId'),
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
        label: 'Edit game',
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
      cta = DabblerButton(
        label: state.isActing ? 'Leaving…' : 'Leave game',
        icon: 'logout',
        tone: DabblerButtonTone.outlined,
        size: DabblerButtonSize.full,
        fullWidth: true,
        disabled: state.isActing,
        onPressed: _confirmLeave,
      );
    } else if (ctrl.isOnWaitlist) {
      cta = const DabblerButton(
        label: 'On waitlist',
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
            ? _joiningLabel(game.joinPolicy)
            : _joinLabel(game),
        icon: state.isActing ? null : _joinIcon(game.joinPolicy),
        size: DabblerButtonSize.full,
        fullWidth: true,
        loading: state.isActing,
        onPressed: ctrl.joinGame,
      );
    }
    return DabblerActionBar(price: gameEntryLabel(game), primary: cta);
  }

  String _joinLabel(GameView game) {
    if (game.isFull && game.allowsWaitlist) return 'Join waitlist';
    switch (game.joinPolicy) {
      case 'request':
        return 'Request to join';
      case 'invite':
        return 'Join (invited)';
      default:
        return 'Join game';
    }
  }

  String _joiningLabel(String policy) =>
      policy == 'request' ? 'Requesting…' : 'Joining…';

  String _joinIcon(String policy) =>
      policy == 'request' ? 'send' : 'tick-circle';

  Future<void> _openEditGame(String gameId, GameViewController ctrl) async {
    final updated = await context.pushNamed(
      RouteNames.editGame,
      pathParameters: {'gameId': gameId},
    );
    if (updated == true) await ctrl.refresh();
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDabblerDialog<bool>(
      context: context,
      builder: (ctx) => DabblerDialog(
        title: 'Leave game?',
        description: 'You will lose your spot and may not be able to rejoin.',
        destructive: true,
        onClose: () => Navigator.pop(ctx, false),
        secondaryAction: DabblerDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(ctx, false),
        ),
        primaryAction: DabblerDialogAction(
          label: 'Leave',
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(gameViewControllerProvider(widget.gameId).notifier).leaveGame();
    }
  }

  Future<void> _confirmRemove(
    GameViewController ctrl,
    GameRosterEntry player,
  ) async {
    final confirmed = await showDabblerDialog<bool>(
      context: context,
      builder: (ctx) => DabblerDialog(
        title: 'Remove ${player.displayName}?',
        description:
            'They will lose their spot and be notified. If the game has a '
            'waitlist, the first player in line takes their place.',
        destructive: true,
        onClose: () => Navigator.pop(ctx, false),
        secondaryAction: DabblerDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(ctx, false),
        ),
        primaryAction: DabblerDialogAction(
          label: 'Remove',
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (confirmed == true) await ctrl.removePlayer(player.profileId);
  }

  String _actionMessage(JoinActionResult action) {
    switch (action) {
      case JoinActionResult.joined:
        return 'You joined the game!';
      case JoinActionResult.waitlisted:
        return 'Added to waitlist.';
      case JoinActionResult.requestSubmitted:
        return 'Join request sent.';
      case JoinActionResult.left:
        return 'You left the game.';
      case JoinActionResult.cancelledRequest:
        return 'Join request cancelled.';
    }
  }
}
