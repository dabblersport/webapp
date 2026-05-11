import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/widgets/dynamic_background.dart';

// Sport-identity colors — intentionally hardcoded, not theme tokens.
const _kGreen = Color(0xFF00C853);
const _kPink  = Color(0xFFFF3376);

Color _sportColor(String? key) {
  switch (key?.toLowerCase()) {
    case 'football': case 'soccer': case 'futsal':
      return const Color(0xFF00C853);
    case 'basketball':
      return const Color(0xFFFF6D00);
    case 'tennis': case 'padel':
      return const Color(0xFFF9A825);
    case 'cricket':
      return const Color(0xFF8D6E63);
    case 'badminton':
      return const Color(0xFFE91E63);
    case 'swimming':
      return const Color(0xFF0288D1);
    case 'running':
      return const Color(0xFFFF7043);
    default:
      return const Color(0xFF7328CE);
  }
}

Color _sportFgColor(String? key) {
  switch (key?.toLowerCase()) {
    case 'football': case 'soccer': case 'futsal':
      return const Color(0xFF0a3d1c);
    default:
      return Colors.white;
  }
}

String _sportEmoji(String? key) {
  switch (key?.toLowerCase()) {
    case 'football': case 'soccer': case 'futsal': return '⚽';
    case 'basketball': return '🏀';
    case 'tennis': case 'padel': return '🎾';
    case 'cricket': return '🏏';
    case 'badminton': return '🏸';
    case 'swimming': return '🏊';
    case 'running': return '🏃';
    case 'equestrian': return '🐎';
    case 'shooting': return '🎯';
    default: return '🏃';
  }
}

class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({super.key, required this.gameId});
  final String gameId;

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  final ScrollController _scroll = ScrollController();
  late final String _previousCategory;

  @override
  void initState() {
    super.initState();
    _previousCategory = AppTheme.activeCategory;
    AppTheme.setActiveCategory('sports');
  }

  @override
  void dispose() {
    AppTheme.setActiveCategory(_previousCategory);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final top  = MediaQuery.of(context).padding.top;
    final state = ref.watch(gameViewControllerProvider(widget.gameId));
    final ctrl  = ref.read(gameViewControllerProvider(widget.gameId).notifier);

    ref.listen(gameViewControllerProvider(widget.gameId), (prev, next) {
      if (!mounted) return;
      if (next.lastAction != null && prev?.lastAction != next.lastAction) {
        _showSnack(_actionMessage(next.lastAction!), isError: false);
      } else if (next.error != null && prev?.error != next.error) {
        _showSnack(next.error!, isError: true);
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          DynamicBackground(scrollController: _scroll),
          _buildBody(state, ctrl, top, cs),
        ],
      ),
      bottomNavigationBar: state.hasGame ? _buildBottomBar(state, ctrl, cs) : null,
    );
  }

  Widget _buildBody(GameViewState state, GameViewController ctrl, double top, ColorScheme cs) {
    if (state.isLoading && !state.hasGame) return _LoadingBody(top: top);
    if (!state.hasGame) {
      return _ErrorBody(
        top: top,
        message: state.error ?? 'Game not found',
        onBack: () => context.pop(),
      );
    }

    final game       = state.game!;
    final sportColor = _sportColor(game.sportKey);

    return Stack(
      children: [
        CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HeroSection(game: game, sportColor: sportColor, top: top),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HostCard(game: game),
                    const SizedBox(height: 14),
                    _StatsRow(game: game, sportColor: sportColor),
                    const SizedBox(height: 14),
                    _DateTimeCard(game: game),
                    if (game.venueName != null) ...[
                      const SizedBox(height: 14),
                      _VenueCard(game: game),
                    ],
                    const SizedBox(height: 18),
                    _DetailsChips(game: game),
                    const SizedBox(height: 18),
                    _RosterSection(state: state, sportColor: sportColor),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: top + 10,
          left: 18,
          right: 18,
          child: Row(
            children: [
              _GlassBtn(icon: Iconsax.arrow_left_copy, onTap: () => context.pop()),
              const Spacer(),
              _GlassBtn(icon: Iconsax.refresh_copy, onTap: ctrl.refresh),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(GameViewState state, GameViewController ctrl, ColorScheme cs) {
    final game         = state.game!;
    final isHost       = ctrl.isHost;
    final isOnRoster   = ctrl.isOnRoster;
    final isOnWaitlist = ctrl.isOnWaitlist;
    final hasPending   = state.hasPendingRequest;
    final isCancelled  = game.isCancelled;
    final isEnded      = game.endAt.isBefore(DateTime.now());
    final sportColor   = _sportColor(game.sportKey);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.surfaceContainerLowest.withValues(alpha: 0), cs.surfaceContainerLowest, cs.surfaceContainerLowest],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnRoster && !isHost
                      ? "You're in"
                      : game.isFree
                          ? 'Free'
                          : game.costCover.replaceAll('_', ' ').capitalize(),
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: isOnRoster && !isHost ? _kGreen : cs.onSurface,
                    letterSpacing: -0.4, height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDateShort(game.startAt),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isHost
                  ? _CtaButton(
                      label: 'Your game', icon: Iconsax.crown_copy,
                      bg: cs.primary.withValues(alpha: 0.08), fg: cs.primary,
                      border: cs.primary.withValues(alpha: 0.3), enabled: false,
                    )
                  : isCancelled || isEnded
                      ? _CtaButton(
                          label: isCancelled ? 'Cancelled' : 'Ended',
                          icon: Iconsax.slash_copy,
                          bg: cs.surfaceContainerLow, fg: cs.onSurfaceVariant, enabled: false,
                        )
                      : isOnRoster
                          ? _CtaButton(
                              label: state.isActing ? 'Leaving…' : 'Leave game',
                              icon: Iconsax.logout_copy,
                              bg: cs.surface, fg: sportColor,
                              border: sportColor.withValues(alpha: 0.5),
                              enabled: !state.isActing, onTap: _confirmLeave,
                            )
                          : isOnWaitlist
                              ? _CtaButton(
                                  label: 'On waitlist', icon: Iconsax.clock_copy,
                                  bg: cs.surfaceContainerLow, fg: cs.onSurfaceVariant, enabled: false,
                                )
                              : hasPending
                                  ? _CtaButton(
                                      label: state.isActing ? 'Cancelling…' : 'Cancel request',
                                      icon: Iconsax.close_square_copy,
                                      bg: cs.surface, fg: cs.error,
                                      border: cs.error.withValues(alpha: 0.3),
                                      enabled: !state.isActing, onTap: ctrl.cancelJoinRequest,
                                    )
                                  : _CtaButton(
                                      label: state.isActing ? _joiningLabel(game.joinPolicy) : _joinLabel(game),
                                      icon: state.isActing ? null : _joinIcon(game.joinPolicy),
                                      bg: sportColor, fg: _sportFgColor(game.sportKey),
                                      enabled: !state.isActing, onTap: ctrl.joinGame,
                                      loading: state.isActing,
                                      shadow: sportColor.withValues(alpha: 0.4),
                                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _joinLabel(GameView game) {
    if (game.isFull && game.allowsWaitlist) return 'Join waitlist';
    switch (game.joinPolicy) {
      case 'request': return 'Request to join';
      case 'invite':  return 'Join (invited)';
      default:        return 'Join game';
    }
  }

  String _joiningLabel(String policy) => policy == 'request' ? 'Requesting…' : 'Joining…';

  IconData _joinIcon(String policy) => policy == 'request' ? Iconsax.send_copy : Iconsax.tick_circle_copy;

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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(gameViewControllerProvider(widget.gameId).notifier).leaveGame();
    }
  }

  String _actionMessage(JoinActionResult action) {
    switch (action) {
      case JoinActionResult.joined:           return 'You joined the game!';
      case JoinActionResult.waitlisted:       return 'Added to waitlist.';
      case JoinActionResult.requestSubmitted: return 'Join request sent.';
      case JoinActionResult.left:             return 'You left the game.';
      case JoinActionResult.cancelledRequest: return 'Join request cancelled.';
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? cs.error : _kGreen,
    ));
  }

  String _formatDateShort(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day   = DateTime(dt.year, dt.month, dt.day);
    final diff  = day.difference(today).inDays;
    final time  = DateFormat('h:mm a').format(dt);
    if (diff == 0) return 'Today · $time';
    if (diff == 1) return 'Tomorrow · $time';
    return '${DateFormat('d MMM').format(dt)} · $time';
  }
}

// =============================================================================
// HERO
// =============================================================================

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.game, required this.sportColor, required this.top});
  final GameView game;
  final Color sportColor;
  final double top;

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final heroTop  = HSLColor.fromColor(cs.primary).withLightness(0.18).toColor();

    return SizedBox(
      height: top + 230.0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [heroTop, sportColor.withValues(alpha: 0.82), sportColor.withValues(alpha: 0.55)],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
          CustomPaint(painter: _FieldPainter(Colors.white)),
          Opacity(opacity: 0.06, child: CustomPaint(painter: _GridPainter())),
          Positioned(
            top: -30, right: -30,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _kPink.withValues(alpha: 0.15)),
            ),
          ),
          Positioned(
            left: 20, right: 20, bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  _StatusBadge(label: game.statusLabel),
                  const SizedBox(width: 8),
                  _SportBadge(
                    emoji: _sportEmoji(game.sportKey),
                    label: [if (game.sportNameEn != null) game.sportNameEn!, if (game.variantNameEn != null) game.variantNameEn!].join(' · '),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(
                  game.title,
                  style: const TextStyle(
                    fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white,
                    letterSpacing: -0.6, height: 1.15,
                    shadows: [Shadow(offset: Offset(0, 2), blurRadius: 12, color: Color(0x44000000))],
                  ),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                if (game.venueName != null || game.areaName != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Iconsax.location_copy, size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        [game.venueName, game.areaName].whereType<String>().join(' · '),
                        style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, cs.surfaceContainerLowest],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final positive = label == 'Live' || label == 'Upcoming';
    final bg  = positive ? _kGreen.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.2);
    final fg  = positive ? const Color(0xFF0a3d1c) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: fg)),
        const SizedBox(width: 5),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.3)),
      ]),
    );
  }
}

class _SportBadge extends StatelessWidget {
  const _SportBadge({required this.emoji, required this.label});
  final String emoji; final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.isEmpty ? emoji : '$emoji $label',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  const _GlassBtn({required this.icon, this.onTap});
  final IconData icon; final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _FieldPainter extends CustomPainter {
  const _FieldPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final w = s.width; final h = s.height;
    canvas.drawRRect(RRect.fromLTRBR(20, 12, w - 20, h - 12, const Radius.circular(6)), p);
    canvas.drawLine(Offset(w / 2, 12), Offset(w / 2, h - 12), p);
    canvas.drawCircle(Offset(w / 2, h / 2), h * 0.26, p);
    canvas.drawCircle(Offset(w / 2, h / 2), 2.5, Paint()..color = color.withValues(alpha: 0.6));
    final bw = w * 0.13; final bh = h * 0.50;
    canvas.drawRect(Rect.fromLTWH(20, (h - bh) / 2, bw, bh), p);
    canvas.drawRect(Rect.fromLTWH(w - 20 - bw, (h - bh) / 2, bw, bh), p);
    final gp = Paint()..color = color.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final gw = w * 0.045; final gh = h * 0.27;
    canvas.drawRect(Rect.fromLTWH(20, (h - gh) / 2, gw, gh), gp);
    canvas.drawRect(Rect.fromLTWH(w - 20 - gw, (h - gh) / 2, gw, gh), gp);
  }

  @override
  bool shouldRepaint(_FieldPainter o) => o.color != color;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white..strokeWidth = 1;
    for (var i = 0; i < 12; i++) { canvas.drawLine(Offset(i * 36.0, 0), Offset(i * 36.0, s.height), p); }
    for (var i = 0; i < 8; i++)  { canvas.drawLine(Offset(0, i * 36.0), Offset(s.width, i * 36.0), p); }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

// =============================================================================
// CONTENT WIDGETS
// =============================================================================

class _HostCard extends StatelessWidget {
  const _HostCard({required this.game});
  final GameView game;

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final name    = game.creatorDisplayName ?? game.creatorUsername ?? 'Host';
    final initials = _initials(name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant, width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primary, _kPink]),
          ),
          child: game.creatorAvatarUrl != null
              ? ClipOval(child: Image.network(game.creatorAvatarUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)))))
              : Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hosted by', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          const SizedBox(height: 1),
          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
        ])),
      ]),
    );
  }

  String _initials(String n) {
    final p = n.trim().split(' ');
    if (p.isEmpty) return '?';
    if (p.length == 1) return p[0][0].toUpperCase();
    return '${p[0][0]}${p[1][0]}'.toUpperCase();
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.game, required this.sportColor});
  final GameView game; final Color sportColor;

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final fill = game.capacity > 0 ? (game.rosterCount / game.capacity).clamp(0.0, 1.0) : 0.0;
    final mins = game.endAt.difference(game.startAt).inMinutes;
    return Row(children: [
      Expanded(flex: 115, child: _StatCard(
        icon: Iconsax.people_copy, iconColor: sportColor,
        value: '${game.rosterCount}/${game.capacity}', label: 'Players',
        progress: fill, progressColor: sportColor,
        sub: game.isFull ? 'Full' : '${game.spotsLeft} spots left',
        subColor: game.isFull ? cs.error : sportColor,
      )),
      const SizedBox(width: 8),
      Expanded(flex: 100, child: _StatCard(
        icon: Iconsax.money_copy, iconColor: _kGreen,
        value: game.isFree ? 'Free' : game.costCover.replaceAll('_', ' ').capitalize(),
        label: 'Entry', valueColor: game.isFree ? _kGreen : null,
        sub: game.isFree ? 'No fees' : null,
      )),
      const SizedBox(width: 8),
      Expanded(flex: 100, child: _StatCard(
        icon: Iconsax.timer_copy, iconColor: cs.primary,
        value: _fmtDur(mins), label: 'Duration',
        sub: '${DateFormat('h a').format(game.startAt)}–${DateFormat('h a').format(game.endAt)}',
      )),
    ]);
  }

  String _fmtDur(int m) {
    if (m <= 0) return '—';
    if (m < 60) return '${m}m';
    final h = m ~/ 60; final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon, required this.iconColor,
    required this.value, required this.label,
    this.valueColor, this.sub, this.subColor,
    this.progress, this.progressColor,
  });
  final IconData icon; final Color iconColor;
  final String value; final String label;
  final Color? valueColor; final String? sub; final Color? subColor;
  final double? progress; final Color? progressColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: valueColor ?? cs.onSurface, height: 1, letterSpacing: -0.4)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        if (progress != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress, minHeight: 5, backgroundColor: cs.surfaceContainerLow,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor ?? cs.primary),
            ),
          ),
        ],
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub!, style: TextStyle(fontSize: 10, color: subColor ?? cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }
}

// ── Date / Time ───────────────────────────────────────────────────────────────

class _DateTimeCard extends StatelessWidget {
  const _DateTimeCard({required this.game});
  final GameView game;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant, width: 1.5),
      ),
      child: Column(children: [
        _InfoRow(icon: Iconsax.calendar_copy, iconColor: cs.primary, label: 'DATE', value: DateFormat('EEEE, MMMM d, y').format(game.startAt)),
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
        _InfoRow(
          icon: Iconsax.clock_copy, iconColor: _kGreen, label: 'TIME',
          value: '${DateFormat('h:mm a').format(game.startAt)} – ${DateFormat('h:mm a').format(game.endAt)}',
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.iconColor, required this.label, required this.value});
  final IconData icon; final Color iconColor; final String label; final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
        ])),
      ]),
    );
  }
}

// ── Venue ─────────────────────────────────────────────────────────────────────

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.game});
  final GameView game;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Venue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.1)),
        const SizedBox(height: 14),
        if (game.venueName != null)
          _InfoRow(icon: Iconsax.buildings_copy, iconColor: cs.primary, label: 'NAME', value: game.venueName!),
        if (game.venueSpaceName != null) ...[
          Divider(height: 20, color: cs.outlineVariant.withValues(alpha: 0.6)),
          _InfoRow(icon: Iconsax.location_copy, iconColor: cs.primary, label: 'SPACE', value: game.venueSpaceName!),
        ],
        if (game.areaName != null) ...[
          Divider(height: 20, color: cs.outlineVariant.withValues(alpha: 0.6)),
          _InfoRow(icon: Iconsax.map_copy, iconColor: cs.primary, label: 'AREA', value: game.areaName!),
        ],
      ]),
    );
  }
}

// ── Details chips ─────────────────────────────────────────────────────────────

class _DetailsChips extends StatelessWidget {
  const _DetailsChips({required this.game});
  final GameView game;

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final chips = [
      (label: game.isPublic ? 'Public' : 'Private', icon: game.isPublic ? Iconsax.eye_copy : Iconsax.lock_copy),
      (label: _policyLabel(game.joinPolicy), icon: _policyIcon(game.joinPolicy)),
      if (game.minSkill != null && game.maxSkill != null)
        (label: 'Skill ${game.minSkill}–${game.maxSkill}', icon: Iconsax.star_copy),
      if (game.benchSlots > 0)
        (label: '${game.benchSlots} bench', icon: Iconsax.people_copy),
      if (game.allowSpectators)
        (label: 'Spectators', icon: Iconsax.eye_copy),
      if (game.allowsWaitlist)
        (label: 'Waitlist on', icon: Iconsax.clock_copy),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.1)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: chips.map((c) => _DetailChip(label: c.label, icon: c.icon)).toList()),
    ]);
  }

  String _policyLabel(String p) {
    switch (p) {
      case 'open':    return 'Open join';
      case 'request': return 'Request to join';
      case 'invite':  return 'Invite only';
      case 'link':    return 'Link join';
      case 'circle':  return 'Circle only';
      case 'squad':   return 'Squad only';
      case 'closed':  return 'Closed';
      default:        return p;
    }
  }

  IconData _policyIcon(String p) {
    switch (p) {
      case 'open':    return Iconsax.unlock_copy;
      case 'request': return Iconsax.send_copy;
      case 'invite':  return Iconsax.sms_copy;
      case 'link':    return Iconsax.link_copy;
      default:        return Iconsax.lock_copy;
    }
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.icon});
  final String label; final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface, borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant, width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cs.onSurface)),
      ]),
    );
  }
}

// ── Roster ────────────────────────────────────────────────────────────────────

class _RosterSection extends StatelessWidget {
  const _RosterSection({required this.state, required this.sportColor});
  final GameViewState state; final Color sportColor;

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final roster   = state.roster;
    final waitlist = state.waitlist;
    final game     = state.game!;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Players', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.1)),
        const SizedBox(width: 6),
        Text('· ${game.rosterCount} of ${game.capacity}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        const Spacer(),
        if (game.spotsLeft > 0)
          Text('${game.spotsLeft} spots left', style: TextStyle(fontSize: 12, color: sportColor, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 10),
      if (roster.isEmpty && waitlist.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant, width: 1.5)),
          child: Center(child: Text('No players yet — be the first to join!', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant), textAlign: TextAlign.center)),
        )
      else
        Container(
          decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant, width: 1.5)),
          child: Column(children: [
            ...roster.asMap().entries.map((e) {
              final isLast = e.key == roster.length - 1 && waitlist.isEmpty;
              return _PlayerRow(name: e.value.displayName, avatarUrl: e.value.avatarUrl, isHost: e.value.isHost, badge: e.value.isHost ? 'Host' : null, showDivider: !isLast);
            }),
            if (waitlist.isNotEmpty) ...[
              const _WaitlistDivider(),
              ...waitlist.asMap().entries.map((e) {
                final isLast = e.key == waitlist.length - 1;
                return _PlayerRow(name: e.value.displayName, avatarUrl: e.value.avatarUrl, isHost: false, badge: '#${e.value.position}', showDivider: !isLast, isWaitlisted: true);
              }),
            ],
          ]),
        ),
      if (game.spotsLeft > 0) ...[
        const SizedBox(height: 8),
        _OpenSpotsCard(spotsLeft: game.spotsLeft, sportColor: sportColor),
      ],
    ]);
  }
}

class _OpenSpotsCard extends StatelessWidget {
  const _OpenSpotsCard({required this.spotsLeft, required this.sportColor});
  final int spotsLeft; final Color sportColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: sportColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sportColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(shape: BoxShape.circle, color: cs.surfaceContainerLow, border: Border.all(color: cs.outlineVariant, width: 1.5)),
          child: Icon(Iconsax.people_copy, size: 16, color: sportColor),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$spotsLeft open spots', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sportColor)),
          const SizedBox(height: 2),
          Text('Invite friends to fill the squad', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: sportColor.withValues(alpha: 0.4), width: 1.5)),
          child: Text('Invite', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sportColor)),
        ),
      ]),
    );
  }
}

class _WaitlistDivider extends StatelessWidget {
  const _WaitlistDivider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.6))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('Waitlist', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600))),
        Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.6))),
      ]),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.name, required this.isHost,
    this.avatarUrl, this.badge, this.showDivider = true, this.isWaitlisted = false,
  });
  final String name; final String? avatarUrl;
  final bool isHost; final String? badge;
  final bool showDivider; final bool isWaitlisted;

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final initials = _initials(name);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary.withValues(alpha: 0.10)),
            child: avatarUrl != null
                ? ClipOval(child: Image.network(avatarUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(child: Text(initials, style: TextStyle(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w700)))))
                : Center(child: Text(initials, style: TextStyle(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: cs.onSurface)),
            if (isHost || isWaitlisted)
              Text(isHost ? 'Organizer' : 'Waitlisted', style: TextStyle(fontSize: 11, color: isHost ? cs.primary : cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ])),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: isHost ? cs.primary.withValues(alpha: 0.12) : cs.surfaceContainerLow, borderRadius: BorderRadius.circular(999)),
              child: Text(badge!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isHost ? cs.primary : cs.onSurfaceVariant, letterSpacing: 0.3)),
            )
          else if (isWaitlisted)
            Icon(Iconsax.clock_copy, size: 16, color: cs.onSurfaceVariant),
        ]),
      ),
      if (showDivider) Divider(height: 1, indent: 64, endIndent: 14, color: cs.outlineVariant.withValues(alpha: 0.5)),
    ]);
  }

  String _initials(String n) {
    final p = n.trim().split(' ');
    if (p.isEmpty) return '?';
    if (p.length == 1) return p[0][0].toUpperCase();
    return '${p[0][0]}${p[1][0]}'.toUpperCase();
  }
}

// ── CTA Button ────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label, required this.bg, required this.fg,
    this.icon, this.border, this.enabled = true,
    this.onTap, this.loading = false, this.shadow,
  });
  final String label; final Color bg; final Color fg;
  final IconData? icon; final Color? border;
  final bool enabled; final VoidCallback? onTap;
  final bool loading; final Color? shadow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: enabled ? bg : bg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: border != null ? Border.all(color: border!, width: 1.5) : null,
          boxShadow: (shadow != null && enabled)
              ? [BoxShadow(color: shadow!, blurRadius: 24, offset: const Offset(0, 8))]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(fg)))
          else if (icon != null) ...[
            Icon(icon, size: 18, color: enabled ? fg : fg.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: enabled ? fg : fg.withValues(alpha: 0.6))),
        ]),
      ),
    );
  }
}

// ── Loading / error ───────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.top});
  final double top;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(child: Column(children: [
      _shim(double.infinity, top + 230, cs),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          _shim(double.infinity, 70, cs),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _shim(double.infinity, 90, cs)),
            const SizedBox(width: 8),
            Expanded(child: _shim(double.infinity, 90, cs)),
            const SizedBox(width: 8),
            Expanded(child: _shim(double.infinity, 90, cs)),
          ]),
          const SizedBox(height: 14),
          _shim(double.infinity, 100, cs),
        ]),
      ),
    ]));
  }

  Widget _shim(double w, double h, ColorScheme cs) => Container(
    width: w, height: h,
    decoration: BoxDecoration(color: cs.outlineVariant.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
  );
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.top, required this.message, required this.onBack});
  final double top; final String message; final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(children: [
      Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Iconsax.warning_2_copy, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.tonal(onPressed: onBack, child: const Text('Go back')),
        ]),
      )),
      Positioned(
        top: top + 10, left: 18,
        child: GestureDetector(
          onTap: onBack,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary.withValues(alpha: 0.10)),
            child: Icon(Iconsax.arrow_left_copy, size: 18, color: cs.onSurface),
          ),
        ),
      ),
    ]);
  }
}

extension _StringExt on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
