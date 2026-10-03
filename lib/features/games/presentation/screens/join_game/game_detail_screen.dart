import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Game details (D01) on the design system only.
///
/// Same provider, controller, routes, join / leave / request / remove flows and
/// deep-link behaviour as before: only the widget tree changed.

/// The colours the design draws the hero in (`--sport-p-600`): the sport
/// theme's brand pair, read through the design system rather than a literal.
DabblerColors _sportColors(DabblerColors colors) => DabblerColors.resolve(
  theme: DabblerTheme.sport,
  brightness: colors.brightness,
);

/// `ds:<seed>` references and storage paths resolve the way the profile screen
/// resolves them, so the picture always matches.
String _seedFor(String? avatarUrl, String name) =>
    extractDsAvatarSeed(avatarUrl) ?? name;

String? _photoFor(String? avatarUrl) => resolveAvatarUrl(avatarUrl);

String _backIcon(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
    ? 'arrow-circle-right'
    : 'arrow-circle-left';

void _toast(BuildContext context, String message, {required bool isError}) {
  DabblerToastProvider.maybeOf(context)?.show(
    DabblerToastSpec(
      message: message,
      tone: isError ? DabblerToastTone.error : DabblerToastTone.success,
    ),
  );
}

class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({
    super.key,
    required this.gameId,
    this.focusRequests = false,
  });
  final String gameId;

  /// When true (join-request notification deep link), auto-scrolls to the
  /// Players section once the game has loaded.
  final bool focusRequests;

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _playersKey = GlobalKey();
  bool _didFocusScroll = false;

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
        _toast(context, _actionMessage(next.lastAction!), isError: false);
      } else if (next.error != null && prev?.error != next.error) {
        _toast(context, next.error!, isError: true);
      }
    });

    return DabblerPage(
      // The hero bleeds under the status bar, so the page must not inset the
      // top itself: an empty top bar turns that inset off and the hero pads
      // the safe area on its own.
      topBar: const SizedBox.shrink(),
      bottomOverlay: state.hasGame ? _buildBottomBar(state, ctrl) : null,
      body: _buildBody(state, ctrl),
    );
  }

  Widget _buildBody(GameViewState state, GameViewController ctrl) {
    final top = MediaQuery.paddingOf(context).top;
    if (state.isLoading && !state.hasGame) return _LoadingBody(top: top);
    if (!state.hasGame) {
      return _ErrorBody(
        top: top,
        message: state.error ?? 'Game not found',
        onBack: () => context.pop(),
      );
    }

    final game = state.game!;

    // Notification deep link: scroll to the Players / requests section once
    // the first full load has settled.
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
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (showBanner)
          SliverToBoxAdapter(
            child: _OpenInAppBanner(gameId: game.id, top: top),
          ),
        SliverToBoxAdapter(
          child: _HeroSection(
            game: game,
            top: showBanner ? 0 : top,
            onBack: () => context.pop(),
            onShare: () => _shareGame(game),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  DabblerSpacing.space6,
                  DabblerSpacing.space6,
                  DabblerSpacing.space6,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SquadSummary(state: state),
                    const SizedBox(height: DabblerSpacing.space5),
                    _StatsGrid(game: game),
                    const SizedBox(height: DabblerSpacing.space5),
                    _HostCard(game: game),
                    if (game.venueName != null) ...[
                      const SizedBox(height: DabblerSpacing.space5),
                      _VenueCard(game: game),
                    ],
                    const SizedBox(height: DabblerSpacing.space5),
                    _DetailsChips(game: game),
                    const SizedBox(height: DabblerSpacing.space5),
                    KeyedSubtree(
                      key: _playersKey,
                      child: _RosterSection(state: state, ctrl: ctrl),
                    ),
                    SizedBox(
                      height:
                          MediaQuery.paddingOf(context).bottom +
                          DabblerSpacing.space11 * 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(GameViewState state, GameViewController ctrl) {
    final colors = DabblerColors.of(context);
    final game = state.game!;
    final isHost = ctrl.isHost;
    final isOnRoster = ctrl.isOnRoster;
    final isOnWaitlist = ctrl.isOnWaitlist;
    final hasPending = state.hasPendingRequest;
    final isCancelled = game.isCancelled;
    final isEnded = game.endAt.isBefore(DateTime.now());

    final Widget cta;
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
    } else if (isOnRoster) {
      cta = DabblerButton(
        label: state.isActing ? 'Leaving…' : 'Leave game',
        icon: 'logout',
        tone: DabblerButtonTone.outlined,
        size: DabblerButtonSize.full,
        fullWidth: true,
        disabled: state.isActing,
        onPressed: _confirmLeave,
      );
    } else if (isOnWaitlist) {
      cta = const DabblerButton(
        label: 'On waitlist',
        icon: 'clock',
        tone: DabblerButtonTone.neutral,
        size: DabblerButtonSize.full,
        fullWidth: true,
        disabled: true,
      );
    } else if (hasPending) {
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

    final inGame = isOnRoster && !isHost;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(top: BorderSide(color: colors.bgTertiary)),
      ),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DabblerText(
                  inGame
                      ? "You're in"
                      : game.isFree
                      ? 'Free'
                      : game.costCover.replaceAll('_', ' ').capitalize(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DabblerType.title3,
                  weight: DabblerTextWeight.bold,
                  tone: inGame
                      ? DabblerTextTone.success
                      : DabblerTextTone.primary,
                ),
                DabblerText(
                  _formatDateShort(game.startAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DabblerType.caption2,
                  tone: DabblerTextTone.tertiary,
                ),
              ],
            ),
          ),
          const SizedBox(width: DabblerSpacing.space5),
          Expanded(child: cta),
        ],
      ),
    );
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

  String _formatDateShort(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = day.difference(today).inDays;
    final time = DateFormat('h:mm a').format(dt);
    if (diff == 0) return 'Today · $time';
    if (diff == 1) return 'Tomorrow · $time';
    return '${DateFormat('d MMM').format(dt)} · $time';
  }
}

// =============================================================================
// HERO
// =============================================================================

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.game,
    required this.top,
    required this.onBack,
    required this.onShare,
  });
  final GameView game;
  final double top;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final sport = _sportColors(DabblerColors.of(context));
    final onSport = sport.onBrand;
    final glass = onSport.withValues(alpha: 0.2);
    final sportLabel = [
      if (game.sportNameEn != null) game.sportNameEn!,
      if (game.variantNameEn != null) game.variantNameEn!,
    ].join(' · ');
    final place = [
      game.venueName,
      game.areaName,
    ].whereType<String>().join(' · ');

    return ColoredBox(
      color: sport.brandPrimary,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          top + DabblerSpacing.space5,
          DabblerSpacing.space6,
          DabblerSpacing.space8,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Translucent on-colour circles over the sport band
                    // (`Details.dc.html:50-58`).
                    DabblerOnColorIconButton(
                      icon: 'arrow-circle-left',
                      mirrorInRtl: true,
                      semanticLabel: 'Back',
                      color: onSport,
                      onPressed: onBack,
                    ),
                    DabblerOnColorIconButton(
                      icon: 'share',
                      semanticLabel: 'Share',
                      color: onSport,
                      onPressed: onShare,
                    ),
                  ],
                ),
                const SizedBox(height: DabblerSpacing.space5),
                Wrap(
                  spacing: DabblerSpacing.space2,
                  runSpacing: DabblerSpacing.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DabblerBadge(label: game.statusLabel, fill: glass),
                    DabblerBadge(
                      label: sportLabel.isEmpty ? 'Sport' : sportLabel,
                      fill: glass,
                      icon: DabblerSportIcon.fromKey(
                        game.sportKey ?? '',
                        size: DabblerSizing.iconXs,
                        color: onSport,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DabblerSpacing.space3),
                DabblerText(
                  game.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DabblerType.largeTitle,
                  tone: DabblerTextTone.onBrand,
                ),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: DabblerSpacing.space2),
                  Row(
                    children: [
                      DabblerIcon(
                        'location',
                        size: DabblerSizing.iconInline,
                        color: onSport,
                      ),
                      const SizedBox(width: DabblerSpacing.space1),
                      Expanded(
                        child: DabblerText(
                          place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DabblerType.footnote,
                          weight: DabblerTextWeight.semibold,
                          tone: DabblerTextTone.onBrand,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CONTENT WIDGETS
// =============================================================================

/// Photos of whoever is on the roster, the headline count and the fill bar.
class _SquadSummary extends StatelessWidget {
  const _SquadSummary({required this.state});
  final GameViewState state;

  @override
  Widget build(BuildContext context) {
    final game = state.game!;
    final fill = game.capacity > 0
        ? (game.rosterCount / game.capacity).clamp(0.0, 1.0)
        : 0.0;
    final shown = state.roster.take(5).toList();
    final extra = game.rosterCount - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (shown.isNotEmpty || extra > 0) ...[
              DabblerAvatarGroup(
                people: [
                  for (final p in shown) _seedFor(p.avatarUrl, p.displayName),
                ],
                imageUrls: [for (final p in shown) _photoFor(p.avatarUrl)],
                overflow: extra > 0 ? extra : 0,
              ),
              const SizedBox(width: DabblerSpacing.space4),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DabblerText(
                    '${game.rosterCount} of ${game.capacity} players in',
                    style: DabblerType.title3,
                    weight: DabblerTextWeight.bold,
                  ),
                  DabblerText(
                    game.isFull ? 'Full' : '${game.spotsLeft} spots left',
                    style: DabblerType.caption1,
                    tone: game.isFull
                        ? DabblerTextTone.error
                        : DabblerTextTone.tertiary,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: DabblerSpacing.space3),
        DabblerProgressBar(
          value: fill,
          size: DabblerProgressBarSize.md,
          tone: game.isFull
              ? DabblerProgressBarTone.error
              : DabblerProgressBarTone.brand,
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.game});
  final GameView game;

  @override
  Widget build(BuildContext context) {
    final mins = game.endAt.difference(game.startAt).inMinutes;
    final hasSkill = game.minSkill != null && game.maxSkill != null;
    return DabblerStatGrid(
      children: [
        DabblerStatTile(
          value: DateFormat('h:mm a').format(game.startAt),
          label: DateFormat('EEE, MMM d').format(game.startAt),
          tone: DabblerStatTileTone.amber,
          span: 3,
        ),
        DabblerStatTile(
          value: _fmtDur(mins),
          label: 'Until ${DateFormat('h:mm a').format(game.endAt)}',
          tone: DabblerStatTileTone.info,
          span: 3,
        ),
        DabblerStatTile(
          value: game.isFree
              ? 'Free'
              : game.costCover.replaceAll('_', ' ').capitalize(),
          label: game.isFree ? 'Entry · No fees' : 'Entry',
          tone: DabblerStatTileTone.ink,
          span: hasSkill ? 3 : 6,
        ),
        if (hasSkill)
          DabblerStatTile(
            value: '${game.minSkill}–${game.maxSkill}',
            label: 'Skill level',
            tone: DabblerStatTileTone.accent,
            span: 3,
          ),
      ],
    );
  }

  String _fmtDur(int m) {
    if (m <= 0) return '—';
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({required this.game});
  final GameView game;

  @override
  Widget build(BuildContext context) {
    final name = game.creatorDisplayName ?? game.creatorUsername ?? 'Creator';
    final creatorProfileId = game.creatorProfileId;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: creatorProfileId == null
          ? null
          // The view no longer exposes a real auth uid for the creator, only
          // creator_profile_id (KAN-87) — pass it in both the path slot and
          // the profileId query param so downstream consumers that check
          // profileId first resolve correctly.
          : () => context.push(
              '${RoutePaths.userProfile}/$creatorProfileId'
              '?profileId=$creatorProfileId',
            ),
      child: DabblerSurface(
        fill: DabblerColors.tileInfo.surface,
        borderColor: DabblerColors.tileInfo.surface,
        radius: DabblerRadius.xl,
        padding: const EdgeInsets.all(DabblerSpacing.space5),
        child: Row(
          children: [
            DabblerAvatar(
              seed: _seedFor(game.creatorAvatarUrl, name),
              imageUrl: _photoFor(game.creatorAvatarUrl),
              size: DabblerAvatarSize.md,
            ),
            const SizedBox(width: DabblerSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DabblerText(
                    'Created by',
                    style: DabblerType.caption2,
                    tone: DabblerTextTone.secondary,
                  ),
                  DabblerText(
                    name,
                    style: DabblerType.subheadline,
                    weight: DabblerTextWeight.semibold,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Where ─────────────────────────────────────────────────────────────────────

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.game});
  final GameView game;

  @override
  Widget build(BuildContext context) {
    final rows = <({String icon, String label, String value})>[
      if (game.venueName != null)
        (icon: 'buildings', label: 'VENUE', value: game.venueName!),
      if (game.venueSpaceName != null)
        (icon: 'location', label: 'SPACE', value: game.venueSpaceName!),
      if (game.areaName != null)
        (icon: 'map', label: 'AREA', value: game.areaName!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DabblerText(
          'Where',
          style: DabblerType.subheadline,
          weight: DabblerTextWeight.semibold,
        ),
        const SizedBox(height: DabblerSpacing.space3),
        DabblerSurface.sunken(
          radius: DabblerRadius.xl,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const DabblerDivider(),
                _InfoRow(
                  icon: rows[i].icon,
                  label: rows[i].label,
                  value: rows[i].value,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DabblerSpacing.space5,
        vertical: DabblerSpacing.space4,
      ),
      child: Row(
        children: [
          DabblerIconTile.named(icon, size: DabblerSizing.iconXl),
          const SizedBox(width: DabblerSpacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DabblerText(
                  label,
                  style: DabblerType.caption2,
                  tone: DabblerTextTone.tertiary,
                ),
                DabblerText(
                  value,
                  style: DabblerType.subheadline,
                  weight: DabblerTextWeight.semibold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Details chips ─────────────────────────────────────────────────────────────

class _DetailsChips extends StatelessWidget {
  const _DetailsChips({required this.game});
  final GameView game;

  @override
  Widget build(BuildContext context) {
    final chips = [
      (
        label: switch (game.listingVisibility) {
          'followers' => 'Followers',
          'private' => 'Private',
          _ => 'Public',
        },
        icon: switch (game.listingVisibility) {
          'followers' => 'people',
          'private' => 'lock',
          _ => 'eye',
        },
      ),
      (
        label: _policyLabel(game.joinPolicy),
        icon: _policyIcon(game.joinPolicy),
      ),
      if (game.minSkill != null && game.maxSkill != null)
        (label: 'Skill ${game.minSkill}–${game.maxSkill}', icon: 'star'),
      if (game.benchSlots > 0)
        (label: '${game.benchSlots} bench', icon: 'people'),
      if (game.allowSpectators) (label: 'Spectators', icon: 'eye'),
      if (game.allowsWaitlist) (label: 'Waitlist on', icon: 'clock'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DabblerText(
          'Details',
          style: DabblerType.subheadline,
          weight: DabblerTextWeight.semibold,
        ),
        const SizedBox(height: DabblerSpacing.space3),
        Wrap(
          spacing: DabblerSpacing.space3,
          runSpacing: DabblerSpacing.space3,
          children: [
            for (final c in chips)
              DabblerBadge(
                label: c.label,
                tone: DabblerBadgeTone.withIcon,
                icon: DabblerIcon(c.icon, size: DabblerSizing.iconXs),
              ),
          ],
        ),
      ],
    );
  }

  String _policyLabel(String p) {
    switch (p) {
      case 'open':
        return 'Open join';
      case 'request':
        return 'Request to join';
      case 'invite':
        return 'Invite only';
      case 'link':
        return 'Link join';
      case 'circle':
        return 'Circle only';
      case 'squad':
        return 'Squad only';
      case 'closed':
        return 'Closed';
      default:
        return p;
    }
  }

  String _policyIcon(String p) {
    switch (p) {
      case 'open':
        return 'unlock';
      case 'request':
        return 'send';
      case 'invite':
        return 'sms';
      case 'link':
        return 'link';
      default:
        return 'lock';
    }
  }
}

// ── Open-in-app banner ────────────────────────────────────────────────────────

/// Mobile-web banner: deep-link into the installed app, or point at the
/// store listing (buttons appear once RoutePaths.appStoreUrl/playStoreUrl
/// are filled in).
class _OpenInAppBanner extends StatefulWidget {
  const _OpenInAppBanner({required this.gameId, required this.top});
  final String gameId;
  final double top;

  @override
  State<_OpenInAppBanner> createState() => _OpenInAppBannerState();
}

class _OpenInAppBannerState extends State<_OpenInAppBanner> {
  bool _dismissed = false;

  String get _storeUrl => defaultTargetPlatform == TargetPlatform.iOS
      ? RoutePaths.appStoreUrl
      : RoutePaths.playStoreUrl;

  Future<void> _openInApp() async {
    // Custom scheme: opens the installed app straight on this game; the
    // browser shows its own "open in Dabbler?" prompt. No-op if missing.
    final uri = Uri.parse('${RoutePaths.deepLinkPrefix}/game/${widget.gameId}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final colors = DabblerColors.of(context);
    return ColoredBox(
      color: colors.bgTertiary,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space5,
          widget.top + DabblerSpacing.space2,
          DabblerSpacing.space2,
          DabblerSpacing.space2,
        ),
        child: Row(
          children: [
            DabblerIcon(
              'flash',
              size: DabblerSizing.iconRow,
              color: colors.brandPrimary,
            ),
            const SizedBox(width: DabblerSpacing.space3),
            Expanded(
              child: DabblerText(
                'Dabbler is better in the app',
                style: DabblerType.footnote,
                weight: DabblerTextWeight.bold,
              ),
            ),
            DabblerButton(
              label: 'Open app',
              tone: DabblerButtonTone.text,
              size: DabblerButtonSize.small,
              onPressed: _openInApp,
            ),
            if (_storeUrl.isNotEmpty)
              DabblerButton(
                label: 'Install',
                tone: DabblerButtonTone.text,
                size: DabblerButtonSize.small,
                onPressed: () => launchUrl(
                  Uri.parse(_storeUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            DabblerButton.icon(
              icon: 'close-circle',
              semanticLabel: 'Dismiss',
              tone: DabblerButtonTone.text,
              size: DabblerButtonSize.small,
              onPressed: () => setState(() => _dismissed = true),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Roster ────────────────────────────────────────────────────────────────────

class _RosterSection extends StatelessWidget {
  const _RosterSection({required this.state, required this.ctrl});
  final GameViewState state;
  final GameViewController ctrl;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final roster = state.roster;
    final waitlist = state.waitlist;
    final game = state.game!;
    // Pending join requests are host-managed; RLS only returns the full
    // list to the host, but gate on isHost anyway so a requester viewing
    // their own row never sees approve/deny controls.
    final requests = ctrl.isHost
        ? state.pendingRequests
        : const <GameJoinRequestEntry>[];
    // Creator can drop players from upcoming games (never themselves).
    final canManagePlayers =
        ctrl.isHost && !game.isCancelled && game.endAt.isAfter(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DabblerText(
              'Players',
              style: DabblerType.subheadline,
              weight: DabblerTextWeight.semibold,
            ),
            const SizedBox(width: DabblerSpacing.space2),
            DabblerText(
              '· ${game.rosterCount} of ${game.capacity}',
              style: DabblerType.caption1,
              tone: DabblerTextTone.tertiary,
            ),
            const Spacer(),
            if (game.spotsLeft > 0)
              DabblerText(
                '${game.spotsLeft} spots left',
                style: DabblerType.caption1,
                weight: DabblerTextWeight.bold,
                tone: DabblerTextTone.brand,
              ),
          ],
        ),
        const SizedBox(height: DabblerSpacing.space3),
        if (requests.isNotEmpty) ...[
          DabblerSurface(
            fill: colors.brandPrimary.withValues(alpha: 0.06),
            borderColor: colors.brandPrimary.withValues(alpha: 0.3),
            radius: DabblerRadius.xl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    DabblerSpacing.space5,
                    DabblerSpacing.space4,
                    DabblerSpacing.space5,
                    0,
                  ),
                  child: DabblerText(
                    '${requests.length} join ${requests.length == 1 ? 'request' : 'requests'}',
                    style: DabblerType.caption2,
                    weight: DabblerTextWeight.bold,
                    tone: DabblerTextTone.brand,
                  ),
                ),
                for (var i = 0; i < requests.length; i++)
                  _RequestRow(
                    request: requests[i],
                    enabled: !state.isActing,
                    showDivider: i != requests.length - 1,
                    onApprove: () =>
                        ctrl.decideJoinRequest(requests[i].id, true),
                    onDeny: () => ctrl.decideJoinRequest(requests[i].id, false),
                  ),
              ],
            ),
          ),
          const SizedBox(height: DabblerSpacing.space3),
        ],
        if (roster.isEmpty && waitlist.isEmpty)
          const DabblerEmptyState(
            title: 'No players yet — be the first to join!',
          )
        else
          DabblerSurface.sunken(
            radius: DabblerRadius.xl,
            child: Column(
              children: [
                ...roster.asMap().entries.map((e) {
                  final isLast = e.key == roster.length - 1 && waitlist.isEmpty;
                  return _PlayerRow(
                    name: e.value.displayName,
                    avatarUrl: e.value.avatarUrl,
                    isHost: e.value.isHost,
                    badge: e.value.isHost ? 'Creator' : null,
                    isMe: e.value.userId == ctrl.currentUserId,
                    showDivider: !isLast,
                    onTap: () => context.push(
                      '${RoutePaths.userProfile}/${e.value.userId}?profileId=${e.value.profileId}',
                    ),
                    onRemove:
                        canManagePlayers && !e.value.isHost && !state.isActing
                        ? () => _confirmRemove(context, e.value)
                        : null,
                  );
                }),
                if (waitlist.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: DabblerSpacing.space5,
                      vertical: DabblerSpacing.space2,
                    ),
                    child: DabblerDivider(label: 'Waitlist'),
                  ),
                  ...waitlist.asMap().entries.map((e) {
                    final isLast = e.key == waitlist.length - 1;
                    return _PlayerRow(
                      name: e.value.displayName,
                      avatarUrl: e.value.avatarUrl,
                      isHost: false,
                      badge: '#${e.value.position}',
                      isMe: e.value.userId == ctrl.currentUserId,
                      showDivider: !isLast,
                      isWaitlisted: true,
                      onTap: () => context.push(
                        '${RoutePaths.userProfile}/${e.value.userId}?profileId=${e.value.profileId}',
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        if (game.spotsLeft > 0) ...[
          const SizedBox(height: DabblerSpacing.space3),
          _OpenSpotsCard(spotsLeft: game.spotsLeft),
        ],
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
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
}

class _OpenSpotsCard extends StatelessWidget {
  const _OpenSpotsCard({required this.spotsLeft});
  final int spotsLeft;

  @override
  Widget build(BuildContext context) {
    return DabblerSurface.sunken(
      radius: DabblerRadius.xl,
      padding: const EdgeInsets.all(DabblerSpacing.space5),
      child: Row(
        children: [
          const DabblerIconTile.named(
            'people',
            tone: DabblerIconTileTone.amber,
            size: DabblerSizing.iconXl,
          ),
          const SizedBox(width: DabblerSpacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DabblerText(
                  '$spotsLeft open spots',
                  style: DabblerType.footnote,
                  weight: DabblerTextWeight.semibold,
                ),
                DabblerText(
                  'Invite friends to fill the squad',
                  style: DabblerType.caption1,
                  tone: DabblerTextTone.tertiary,
                ),
              ],
            ),
          ),
          const DabblerBadge(label: 'Invite'),
        ],
      ),
    );
  }
}

/// Pending join request row — avatar + name with approve / deny actions.
/// Rendered only for the host.
class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.enabled,
    required this.showDivider,
    required this.onApprove,
    required this.onDeny,
  });
  final GameJoinRequestEntry request;
  final bool enabled;
  final bool showDivider;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DabblerSpacing.space5,
            vertical: DabblerSpacing.space3,
          ),
          child: Row(
            children: [
              // Avatar + name open the requester's profile so the host can vet
              // them before deciding; the trailing buttons keep approve/deny.
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push(
                    '${RoutePaths.userProfile}/${request.userId}?profileId=${request.profileId}',
                  ),
                  child: Row(
                    children: [
                      DabblerAvatar(
                        seed: _seedFor(request.avatarUrl, request.displayName),
                        imageUrl: _photoFor(request.avatarUrl),
                        size: DabblerAvatarSize.sm,
                      ),
                      const SizedBox(width: DabblerSpacing.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DabblerText(
                              request.displayName,
                              style: DabblerType.footnote,
                              weight: DabblerTextWeight.semibold,
                            ),
                            DabblerText(
                              'Wants to join',
                              style: DabblerType.caption2,
                              tone: DabblerTextTone.tertiary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DabblerButton.icon(
                icon: 'tick-circle',
                semanticLabel: 'Approve ${request.displayName}',
                tone: DabblerButtonTone.primary,
                size: DabblerButtonSize.small,
                disabled: !enabled,
                onPressed: enabled ? onApprove : null,
              ),
              const SizedBox(width: DabblerSpacing.space3),
              DabblerButton.icon(
                icon: 'close-circle',
                semanticLabel: 'Deny ${request.displayName}',
                tone: DabblerButtonTone.neutral,
                size: DabblerButtonSize.small,
                disabled: !enabled,
                onPressed: enabled ? onDeny : null,
              ),
            ],
          ),
        ),
        if (showDivider) const DabblerDivider(inset: 64),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.name,
    required this.isHost,
    this.avatarUrl,
    this.badge,
    this.showDivider = true,
    this.isWaitlisted = false,
    this.isMe = false,
    this.onTap,
    this.onRemove,
  });
  final String name;
  final String? avatarUrl;
  final bool isHost;
  final String? badge;
  final bool showDivider;
  final bool isWaitlisted;

  /// Adds a "You" pill so the viewer can spot themselves in the list.
  final bool isMe;

  /// Opens the player's profile.
  final VoidCallback? onTap;

  /// Creator-only: drops this player from the game (with confirmation).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DabblerSpacing.space5,
              vertical: DabblerSpacing.space4,
            ),
            child: Row(
              children: [
                DabblerAvatar(
                  seed: _seedFor(avatarUrl, name),
                  imageUrl: _photoFor(avatarUrl),
                  size: DabblerAvatarSize.sm,
                ),
                const SizedBox(width: DabblerSpacing.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DabblerText(
                        name,
                        style: DabblerType.footnote,
                        weight: DabblerTextWeight.semibold,
                      ),
                      if (isHost || isWaitlisted)
                        DabblerText(
                          isHost ? 'Creator' : 'Waitlisted',
                          style: DabblerType.caption1,
                          tone: DabblerTextTone.tertiary,
                        ),
                    ],
                  ),
                ),
                if (isMe) ...[
                  DabblerBadge(label: 'You', status: colors.success),
                  if (badge != null || isWaitlisted)
                    const SizedBox(width: DabblerSpacing.space2),
                ],
                if (badge != null)
                  DabblerBadge(
                    label: badge!,
                    tone: isHost
                        ? DabblerBadgeTone.defaultTone
                        : DabblerBadgeTone.withIcon,
                  )
                else if (isWaitlisted)
                  DabblerIcon(
                    'clock',
                    size: DabblerSizing.iconInline,
                    color: colors.textTertiary,
                  ),
                if (onRemove != null) ...[
                  const SizedBox(width: DabblerSpacing.space3),
                  DabblerButton.icon(
                    icon: 'trash',
                    semanticLabel: 'Remove $name from game',
                    tone: DabblerButtonTone.neutral,
                    size: DabblerButtonSize.small,
                    onPressed: onRemove,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider) const DabblerDivider(inset: 64),
      ],
    );
  }
}

// ── Loading / error ───────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.top});
  final double top;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          DabblerSkeleton.rect(
            width: double.infinity,
            height: top + 230,
            radius: 0,
          ),
          const SizedBox(height: DabblerSpacing.space5),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DabblerSpacing.space6,
            ),
            child: Column(
              children: [
                const DabblerSkeleton.rect(
                  width: double.infinity,
                  height: DabblerSizing.skeletonBlockHeight,
                ),
                const SizedBox(height: DabblerSpacing.space5),
                Row(
                  children: const [
                    Expanded(
                      child: DabblerSkeleton.rect(
                        height: DabblerSizing.skeletonBlockHeight,
                      ),
                    ),
                    SizedBox(width: DabblerSpacing.space3),
                    Expanded(
                      child: DabblerSkeleton.rect(
                        height: DabblerSizing.skeletonBlockHeight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DabblerSpacing.space5),
                const DabblerSkeleton.rect(
                  width: double.infinity,
                  height: DabblerSizing.skeletonBlockHeight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.top,
    required this.message,
    required this.onBack,
  });
  final double top;
  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            DabblerSpacing.space6,
            top + DabblerSpacing.space5,
            DabblerSpacing.space6,
            0,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: DabblerButton.icon(
              icon: _backIcon(context),
              semanticLabel: 'Back',
              tone: DabblerButtonTone.neutral,
              onPressed: onBack,
            ),
          ),
        ),
        Expanded(
          child: DabblerEmptyState.error(
            icon: 'warning-2',
            title: message,
            retryLabel: 'Go back',
            onRetry: onBack,
          ),
        ),
      ],
    );
  }
}

extension _StringExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
