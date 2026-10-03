import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/core/feed/post_layout_resolver.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Top-level router — dispatches each sealed [ActiveEvent] variant to its
/// dedicated card widget. Exhaustive: a new variant is a compile error.
class ActiveEventCard extends StatelessWidget {
  const ActiveEventCard({super.key, required this.event});

  final ActiveEvent event;

  @override
  Widget build(BuildContext context) {
    return switch (event) {
      final PlayerJoinedEvent e => GroupedJoinCard(event: e),
      final GameCreatedEvent e => GameCard(event: e),
      final PostCreatedEvent e => PostCard(event: e),
      final NewUserEvent e => NewUserCard(event: e),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

String _ago(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(dt);
}

/// A [DabblerType] step resolved for the ambient direction, in [color].
TextStyle _type(
  BuildContext context,
  DabblerTypeStyle step,
  Color color, {
  FontWeight? weight,
}) => step
    .resolveForDirection(Directionality.of(context))
    .copyWith(color: color, fontWeight: weight);

const double _gutter = DabblerSpacing.space6;

// ─────────────────────────────────────────────────────────────────────────────
// 1. GroupedJoinCard  (player_joined_game)
// ─────────────────────────────────────────────────────────────────────────────

class GroupedJoinCard extends StatelessWidget {
  const GroupedJoinCard({super.key, required this.event});
  final PlayerJoinedEvent event;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    final int count = event.joinCount;
    final bool isGrouped = count > 1;
    final String? gameId = event.gameId;

    final String title = isGrouped
        ? '$count players joined this game'
        : 'A player joined this game';
    final String meta = <String>[
      if (event.sport != null) event.sport!,
      if (event.venueName != null) event.venueName!,
      _ago(event.createdAt),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: _gutter,
        vertical: DabblerSpacing.space1,
      ),
      child: DabblerCard(
        onTap: gameId != null
            ? () => context.push(RoutePaths.gameDetail(gameId))
            : null,
        enabled: gameId != null,
        padding: const EdgeInsets.all(DabblerSpacing.space4),
        child: Row(
          children: <Widget>[
            const DabblerIconTile.named('flash'),
            const SizedBox(width: DabblerSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: _type(
                      context,
                      DabblerType.subheadline,
                      colors.textPrimary,
                      weight: DabblerType.semibold,
                    ),
                  ),
                  if (event.gameTitle != null)
                    Text(
                      event.gameTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _type(
                        context,
                        DabblerType.footnote,
                        colors.textSecondary,
                      ),
                    ),
                  if (event.venueName != null || event.sport != null)
                    Text(
                      meta,
                      style: _type(
                        context,
                        DabblerType.caption1,
                        colors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            if (isGrouped) ...<Widget>[
              const SizedBox(width: DabblerSpacing.space2),
              DabblerBadge(label: '+$count'),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. GameCard  (game_created)
// ─────────────────────────────────────────────────────────────────────────────

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.event});
  final GameCreatedEvent event;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    final String? gameId = event.gameId;
    void open() => context.push(RoutePaths.gameDetail(gameId!));

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: _gutter,
        vertical: DabblerSpacing.space1,
      ),
      child: DabblerCard(
        onTap: gameId != null ? open : null,
        enabled: gameId != null,
        padding: const EdgeInsets.all(_gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    event.gameTitle ?? 'New Game',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _type(
                      context,
                      DabblerType.headline,
                      colors.textPrimary,
                    ),
                  ),
                ),
                if (event.sport != null) ...<Widget>[
                  const SizedBox(width: DabblerSpacing.space2),
                  DabblerBadge(label: event.sport!),
                ],
              ],
            ),
            if (event.venueName != null) ...<Widget>[
              const SizedBox(height: DabblerSpacing.space2),
              Row(
                children: <Widget>[
                  DabblerIcon(
                    'location',
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: DabblerSpacing.space2),
                  Expanded(
                    child: Text(
                      event.venueName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _type(
                        context,
                        DabblerType.footnote,
                        colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: DabblerSpacing.space2),
            Row(
              children: <Widget>[
                DabblerIcon('clock', size: 16, color: colors.textSecondary),
                const SizedBox(width: DabblerSpacing.space2),
                Text(
                  _ago(event.createdAt),
                  style: _type(
                    context,
                    DabblerType.footnote,
                    colors.textSecondary,
                  ),
                ),
                const Spacer(),
                DabblerButton(
                  label: 'Join Game',
                  size: DabblerButtonSize.small,
                  onPressed: gameId != null ? open : null,
                  disabled: gameId == null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. PostCard  (post_created) — renders the real Post via resolvePostLayout
// ─────────────────────────────────────────────────────────────────────────────

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.event});
  final PostCreatedEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postId = event.postId;
    if (postId == null || postId.isEmpty) return const SizedBox.shrink();

    final asyncPost = ref.watch(postDetailProvider(postId));

    return asyncPost.when(
      data: (post) => resolvePostLayout(post),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space4),
        child: Center(child: DabblerSpinner(size: DabblerSpinnerSize.sm)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. NewUserCard  (user_joined)
// ─────────────────────────────────────────────────────────────────────────────

class NewUserCard extends StatelessWidget {
  const NewUserCard({super.key, required this.event});
  final NewUserEvent event;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    final String name = event.displayName ?? 'Someone';
    final TextStyle base = _type(
      context,
      DabblerType.subheadline,
      colors.textPrimary,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: event.profileId != null
          ? () => context.push(RoutePaths.profile)
          : null,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: _gutter,
          vertical: DabblerSpacing.space2,
        ),
        child: Row(
          children: <Widget>[
            DabblerAvatar(seed: name, size: DabblerAvatarSize.sm),
            const SizedBox(width: DabblerSpacing.space4),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: base,
                  children: <InlineSpan>[
                    TextSpan(
                      text: name,
                      style: base.copyWith(fontWeight: DabblerType.semibold),
                    ),
                    const TextSpan(text: ' joined Dabbler'),
                    if (event.sport != null)
                      TextSpan(
                        text: ' · ${event.sport}',
                        style: base.copyWith(color: colors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: DabblerSpacing.space2),
            Text(
              _ago(event.createdAt),
              style: _type(
                context,
                DabblerType.footnote,
                colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
