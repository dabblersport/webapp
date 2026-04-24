import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/widgets/dynamic_background.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final String gameId;

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final top = MediaQuery.of(context).padding.top;

    final state = ref.watch(gameViewControllerProvider(widget.gameId));
    final ctrl = ref.read(gameViewControllerProvider(widget.gameId).notifier);

    // Show snack on action result / error change
    ref.listen(gameViewControllerProvider(widget.gameId), (prev, next) {
      if (!mounted) return;
      if (next.lastAction != null && prev?.lastAction != next.lastAction) {
        _showSnack(context, cs, _actionMessage(next.lastAction!), isError: false);
      } else if (next.error != null && prev?.error != next.error) {
        _showSnack(context, cs, next.error!, isError: true);
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          DynamicBackground(scrollController: _scroll),
          _buildContent(state, ctrl, top, cs, tt),
        ],
      ),
      bottomNavigationBar: state.hasGame
          ? _buildBottomBar(state, ctrl, cs, tt)
          : null,
    );
  }

  Widget _buildContent(
    GameViewState state,
    GameViewController ctrl,
    double top,
    ColorScheme cs,
    TextTheme tt,
  ) {
    if (state.isLoading && !state.hasGame) {
      return _LoadingBody(top: top, cs: cs);
    }

    if (!state.hasGame) {
      return _ErrorBody(
        top: top,
        cs: cs,
        tt: tt,
        message: state.error ?? 'Game not found',
        onBack: () => context.pop(),
      );
    }

    final game = state.game!;
    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: top + 8)),
        // Header row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _HeaderRow(onBack: () => context.pop(), onRefresh: ctrl.refresh),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        // Hero card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _HeroCard(game: game, cs: cs, tt: tt),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        // Stats row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _StatsRow(game: game, cs: cs, tt: tt),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        // Date/time card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DateTimeCard(game: game, cs: cs, tt: tt),
          ),
        ),
        // Venue
        if (game.venueName != null) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _VenueCard(game: game, cs: cs, tt: tt),
            ),
          ),
        ],
        // Skill / rules chips
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DetailsChips(game: game, cs: cs, tt: tt),
          ),
        ),
        // Roster section
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _RosterSection(state: state, cs: cs, tt: tt),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
        ),
      ],
    );
  }

  // ─── Bottom bar ───────────────────────────────────────────────────────────

  Widget _buildBottomBar(
    GameViewState state,
    GameViewController ctrl,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final game = state.game!;
    final isHost = ctrl.isHost;
    final isOnRoster = ctrl.isOnRoster;
    final isOnWaitlist = ctrl.isOnWaitlist;
    final hasPending = state.hasPendingRequest;
    final isCancelled = game.isCancelled;
    final isEnded = game.endAt.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Left: summary
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.isFree ? 'Free' : game.costCover.replaceAll('_', ' ').capitalize(),
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    _formatDateShort(game.startAt),
                    style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right: action button
            if (isHost)
              _ActionButton(
                label: 'Your game',
                icon: Iconsax.crown_copy,
                bg: cs.secondaryContainer,
                fg: cs.onSecondaryContainer,
                enabled: false,
              )
            else if (isCancelled || isEnded)
              _ActionButton(
                label: isCancelled ? 'Cancelled' : 'Ended',
                icon: Iconsax.slash_copy,
                bg: cs.surfaceContainerHighest,
                fg: cs.onSurfaceVariant,
                enabled: false,
              )
            else if (isOnRoster)
              _ActionButton(
                label: state.isActing ? 'Leaving…' : 'Leave game',
                icon: Iconsax.logout_copy,
                bg: cs.errorContainer,
                fg: cs.onErrorContainer,
                enabled: !state.isActing,
                onTap: _confirmLeave,
              )
            else if (isOnWaitlist)
              _ActionButton(
                label: 'On waitlist',
                icon: Iconsax.clock_copy,
                bg: cs.surfaceContainerHighest,
                fg: cs.onSurfaceVariant,
                enabled: false,
              )
            else if (hasPending)
              _ActionButton(
                label: state.isActing ? 'Cancelling…' : 'Cancel request',
                icon: Iconsax.close_square_copy,
                bg: cs.errorContainer,
                fg: cs.onErrorContainer,
                enabled: !state.isActing,
                onTap: ctrl.cancelJoinRequest,
              )
            else
              _ActionButton(
                label: state.isActing
                    ? _joiningLabel(game.joinPolicy)
                    : _joinLabel(game),
                icon: state.isActing
                    ? null
                    : _joinIcon(game.joinPolicy),
                bg: cs.primary,
                fg: cs.onPrimary,
                enabled: !state.isActing,
                onTap: ctrl.joinGame,
                loading: state.isActing,
              ),
          ],
        ),
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

  String _joiningLabel(String policy) {
    switch (policy) {
      case 'request':
        return 'Requesting…';
      default:
        return 'Joining…';
    }
  }

  IconData _joinIcon(String policy) {
    switch (policy) {
      case 'request':
        return Iconsax.send_copy;
      default:
        return Iconsax.tick_circle_copy;
    }
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave game?'),
        content: const Text('You will lose your spot and may not be able to rejoin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(gameViewControllerProvider(widget.gameId).notifier).leaveGame();
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _actionMessage(JoinActionResult action) {
    switch (action) {
      case JoinActionResult.joined:
        return 'You joined the game!';
      case JoinActionResult.waitlisted:
        return 'Added to waitlist. You\'ll be notified if a spot opens.';
      case JoinActionResult.requestSubmitted:
        return 'Join request sent. The host will review it.';
      case JoinActionResult.left:
        return 'You left the game.';
      case JoinActionResult.cancelledRequest:
        return 'Join request cancelled.';
    }
  }

  void _showSnack(BuildContext context, ColorScheme cs, String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? cs.error : cs.primary,
      ),
    );
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
// SUB-WIDGETS
// =============================================================================

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.onBack, required this.onRefresh});
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _CircleBtn(icon: Iconsax.arrow_left_copy, cs: cs, onTap: onBack),
        const Spacer(),
        _CircleBtn(icon: Iconsax.refresh_copy, cs: cs, onTap: onRefresh),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.cs, this.onTap});
  final IconData icon;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: cs.onSurface),
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.game, required this.cs, required this.tt});
  final GameView game;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_sportEmoji(game.sportKey ?? ''), style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              _Chip(label: game.statusLabel, color: statusColor, cs: cs, tt: tt),
              if (!game.isPublic) ...[
                const SizedBox(width: 6),
                _PillChip(label: 'Private', icon: Iconsax.lock_copy, cs: cs, tt: tt),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            game.title,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (game.sportNameEn != null)
                _PillChip(label: game.sportNameEn!, icon: Iconsax.game_copy, cs: cs, tt: tt),
              if (game.variantNameEn != null)
                _PillChip(label: game.variantNameEn!, icon: Iconsax.people_copy, cs: cs, tt: tt),
              if (game.allowsWaitlist)
                _PillChip(label: 'Waitlist on', icon: Iconsax.clock_copy, cs: cs, tt: tt),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor() {
    switch (game.statusLabel) {
      case 'Live':
        return const Color(0xFF00A63E);
      case 'Cancelled':
      case 'Ended':
        return cs.error;
      default:
        return cs.primary;
    }
  }

  String _sportEmoji(String key) {
    switch (key.toLowerCase()) {
      case 'football':
      case 'soccer':
      case 'futsal':
        return '⚽';
      case 'basketball':
        return '🏀';
      case 'tennis':
      case 'padel':
        return '🎾';
      case 'cricket':
        return '🏏';
      case 'badminton':
        return '🏸';
      case 'swimming':
        return '🏊';
      case 'running':
        return '🏃';
      case 'equestrian':
        return '🐎';
      case 'shooting':
        return '🎯';
      default:
        return '🏃';
    }
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.game, required this.cs, required this.tt});
  final GameView game;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final fill = game.capacity > 0 ? game.rosterCount / game.capacity : 0.0;
    final durationMins = game.endAt.difference(game.startAt).inMinutes;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Iconsax.people_copy,
            label: 'Players',
            value: '${game.rosterCount}/${game.capacity}',
            sub: game.isFull ? 'Full' : '${game.spotsLeft} left',
            subColor: game.isFull ? cs.error : const Color(0xFF00A63E),
            progress: fill.clamp(0.0, 1.0),
            cs: cs,
            tt: tt,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Iconsax.money_copy,
            label: 'Entry',
            value: game.isFree ? 'Free' : game.costCover.replaceAll('_', ' ').capitalize(),
            cs: cs,
            tt: tt,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Iconsax.timer_copy,
            label: 'Duration',
            value: _formatDuration(durationMins),
            cs: cs,
            tt: tt,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int mins) {
    if (mins <= 0) return '—';
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
    this.sub,
    this.subColor,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  final double? progress;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface),
          ),
          const SizedBox(height: 2),
          Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress! >= 1.0 ? cs.error : cs.primary,
                ),
              ),
            ),
          ],
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: tt.labelSmall?.copyWith(
                color: subColor ?? cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Date/time card ────────────────────────────────────────────────────────────

class _DateTimeCard extends StatelessWidget {
  const _DateTimeCard({required this.game, required this.cs, required this.tt});
  final GameView game;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Iconsax.calendar_copy,
            label: 'Date',
            value: DateFormat('EEEE, MMMM d, y').format(game.startAt),
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Iconsax.clock_copy,
            label: 'Time',
            value:
                '${DateFormat('h:mm a').format(game.startAt)} – ${DateFormat('h:mm a').format(game.endAt)}',
            cs: cs,
            tt: tt,
          ),
        ],
      ),
    );
  }
}

// ── Venue card ────────────────────────────────────────────────────────────────

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.game, required this.cs, required this.tt});
  final GameView game;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Venue',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
          const SizedBox(height: 14),
          if (game.venueName != null)
            _InfoRow(
              icon: Iconsax.buildings_copy,
              label: 'Name',
              value: game.venueName!,
              cs: cs,
              tt: tt,
            ),
          if (game.venueSpaceName != null) ...[
            const SizedBox(height: 14),
            _InfoRow(
              icon: Iconsax.location_copy,
              label: 'Space',
              value: game.venueSpaceName!,
              cs: cs,
              tt: tt,
            ),
          ],
          if (game.areaName != null) ...[
            const SizedBox(height: 14),
            _InfoRow(
              icon: Iconsax.map_copy,
              label: 'Area',
              value: game.areaName!,
              cs: cs,
              tt: tt,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Details chips ─────────────────────────────────────────────────────────────

class _DetailsChips extends StatelessWidget {
  const _DetailsChips({required this.game, required this.cs, required this.tt});
  final GameView game;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _PillChip(
        label: game.isPublic ? 'Public' : 'Private',
        icon: game.isPublic ? Iconsax.eye_copy : Iconsax.lock_copy,
        cs: cs,
        tt: tt,
      ),
      _PillChip(
        label: _policyLabel(game.joinPolicy),
        icon: _policyIcon(game.joinPolicy),
        cs: cs,
        tt: tt,
      ),
    ];

    if (game.minSkill != null && game.maxSkill != null) {
      chips.add(_PillChip(
        label: 'Skill ${game.minSkill}–${game.maxSkill}',
        icon: Iconsax.star_copy,
        cs: cs,
        tt: tt,
      ));
    }

    if (game.benchSlots > 0) {
      chips.add(_PillChip(
        label: '${game.benchSlots} bench',
        icon: Iconsax.people_copy,
        cs: cs,
        tt: tt,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Details',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }

  String _policyLabel(String policy) {
    switch (policy) {
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
        return policy;
    }
  }

  IconData _policyIcon(String policy) {
    switch (policy) {
      case 'open':
        return Iconsax.unlock_copy;
      case 'request':
        return Iconsax.send_copy;
      case 'invite':
        return Iconsax.sms_copy;
      case 'link':
        return Iconsax.link_copy;
      default:
        return Iconsax.lock_copy;
    }
  }
}

// ── Roster section ────────────────────────────────────────────────────────────

class _RosterSection extends StatelessWidget {
  const _RosterSection({required this.state, required this.cs, required this.tt});
  final GameViewState state;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final roster = state.roster;
    final waitlist = state.waitlist;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Players',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: roster.isEmpty && waitlist.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No players yet — be the first to join!',
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    ...roster.asMap().entries.map((e) {
                      final isLast = e.key == roster.length - 1 && waitlist.isEmpty;
                      return _PlayerRow(
                        name: e.value.displayName,
                        avatarUrl: e.value.avatarUrl,
                        isHost: e.value.isHost,
                        badge: e.value.isHost ? 'Host' : null,
                        showDivider: !isLast,
                        cs: cs,
                        tt: tt,
                      );
                    }),
                    if (waitlist.isNotEmpty) ...[
                      _WaitlistDivider(cs: cs, tt: tt),
                      ...waitlist.asMap().entries.map((e) {
                        final isLast = e.key == waitlist.length - 1;
                        return _PlayerRow(
                          name: e.value.displayName,
                          avatarUrl: e.value.avatarUrl,
                          isHost: false,
                          badge: '#${e.value.position}',
                          showDivider: !isLast,
                          cs: cs,
                          tt: tt,
                          isWaitlisted: true,
                        );
                      }),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _WaitlistDivider extends StatelessWidget {
  const _WaitlistDivider({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.5))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Waitlist',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.name,
    required this.isHost,
    required this.cs,
    required this.tt,
    this.avatarUrl,
    this.badge,
    this.showDivider = true,
    this.isWaitlisted = false,
  });

  final String name;
  final String? avatarUrl;
  final bool isHost;
  final String? badge;
  final bool showDivider;
  final bool isWaitlisted;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _InitialsWidget(initials: initials, cs: cs, tt: tt),
                        ),
                      )
                    : _InitialsWidget(initials: initials, cs: cs, tt: tt),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    if (isHost || isWaitlisted)
                      Text(
                        isHost ? 'Organizer' : 'Waitlisted',
                        style: tt.labelSmall?.copyWith(
                          color: isHost ? cs.primary : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHost ? cs.primaryContainer : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: tt.labelSmall?.copyWith(
                      color: isHost ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (isWaitlisted)
                Icon(Iconsax.clock_copy, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 66,
            endIndent: 16,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _InitialsWidget extends StatelessWidget {
  const _InitialsWidget({required this.initials, required this.cs, required this.tt});
  final String initials;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
    this.enabled = true,
    this.onTap,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final Color bg;
  final Color fg;
  final bool enabled;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.6),
        disabledForegroundColor: fg.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            )
          : icon != null
              ? Icon(icon)
              : const SizedBox.shrink(),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ── Shared pill chips ─────────────────────────────────────────────────────────

class _PillChip extends StatelessWidget {
  const _PillChip({required this.label, required this.icon, required this.cs, required this.tt});
  final String label;
  final IconData icon;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 5),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.cs, required this.tt});
  final String label;
  final Color color;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
  });
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Loading / error bodies ─────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.top, required this.cs});
  final double top;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: top + 8)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _shimmer(40, 40, cs, circle: true),
                const Spacer(),
                _shimmer(40, 40, cs, circle: true),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _shimmer(double.infinity, 140, cs),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _shimmer(double.infinity, 90, cs)),
                  const SizedBox(width: 10),
                  Expanded(child: _shimmer(double.infinity, 90, cs)),
                  const SizedBox(width: 10),
                  Expanded(child: _shimmer(double.infinity, 90, cs)),
                ]),
                const SizedBox(height: 12),
                _shimmer(double.infinity, 100, cs),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmer(double w, double h, ColorScheme cs, {bool circle = false}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.08),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(12),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.top,
    required this.cs,
    required this.tt,
    required this.message,
    required this.onBack,
  });
  final double top;
  final ColorScheme cs;
  final TextTheme tt;
  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: top + 8)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Iconsax.arrow_left_copy, size: 20, color: cs.onSurface),
              ),
            ),
          ),
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.warning_2_copy, size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.tonal(onPressed: onBack, child: const Text('Go back')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── String extension ──────────────────────────────────────────────────────────

extension _StringExt on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
