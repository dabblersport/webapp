import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/core/design_system/design_system.dart';
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

Widget _avatarWidget(
  String? url,
  String fallback,
  ColorScheme cs,
  double radius,
) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: cs.primaryContainer,
    backgroundImage: url != null ? NetworkImage(url) : null,
    child: url == null
        ? Text(
            fallback.isNotEmpty ? fallback[0].toUpperCase() : '?',
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.85,
            ),
          )
        : null,
  );
}

/// Small stacked-avatars row — shows up to [max] circles, then "+N" label.
class _StackedAvatars extends StatelessWidget {
  const _StackedAvatars({required this.urls});

  final List<String> urls;
  static const int max = 4;
  static const double radius = 14;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = urls.take(max).toList();
    final extra = urls.length - visible.length;
    const overlap = 10.0;
    final total = visible.length * (radius * 2 - overlap) + overlap;

    return SizedBox(
      width: total + (extra > 0 ? radius * 2 : 0),
      height: radius * 2,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * (radius * 2 - overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: radius,
                  backgroundImage: NetworkImage(visible[i]),
                  backgroundColor: cs.primaryContainer,
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: visible.length * (radius * 2 - overlap),
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.secondaryContainer,
                  border: Border.all(color: cs.surface, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '+$extra',
                    style: TextStyle(
                      fontSize: radius * 0.7,
                      fontWeight: FontWeight.bold,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. GroupedJoinCard  (player_joined_game)
//    🔴 Live — compact card with stacked avatars + flame badge
// ─────────────────────────────────────────────────────────────────────────────

class GroupedJoinCard extends StatelessWidget {
  const GroupedJoinCard({super.key, required this.event});
  final PlayerJoinedEvent event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = event.joinCount;
    final isGrouped = count > 1;

    // Stacked avatar URLs are parsed into the typed variant at construction.
    final avatarUrls = event.avatarUrls;

    return InkWell(
      onTap: event.gameId != null
          ? () => context.push(RoutePaths.gameDetail(event.gameId!))
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.secondary.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('🔥', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGrouped
                        ? '🔥 $count players joined this game'
                        : 'A player joined this game',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                  if (event.gameTitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.gameTitle!,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSecondaryContainer.withValues(alpha: 0.75),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (event.venueName != null || event.sport != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (event.sport != null) event.sport!,
                        if (event.venueName != null) event.venueName!,
                        _ago(event.createdAt),
                      ].join(' · '),
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSecondaryContainer.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Stacked avatars or count badge
            if (avatarUrls.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              _StackedAvatars(urls: avatarUrls),
            ] else if (isGrouped) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cs.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+$count',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. GameCard  (game_created)
//    🟢 Discovery — highlighted card with sport pill + "Join Game" CTA
// ─────────────────────────────────────────────────────────────────────────────

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.event});
  final GameCreatedEvent event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Card.filled(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: event.gameId != null
              ? () => context.push(RoutePaths.gameDetail(event.gameId!))
              : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + sport pill
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.gameTitle ?? 'New Game',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (event.sport != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          event.sport!,
                          style: tt.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (event.venueName != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.venueName!,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _ago(event.createdAt),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(88, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: event.gameId != null
                          ? () =>
                              context.push(RoutePaths.gameDetail(event.gameId!))
                          : null,
                      child: const Text('Join Game'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. PostCard  (post_created)
//    🔵 Social — renders the real Post via FeedPostCard / resolvePostLayout
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
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. NewUserCard  (user_joined)
//    🔴 Live — welcome chip with avatar + name
// ─────────────────────────────────────────────────────────────────────────────

class NewUserCard extends StatelessWidget {
  const NewUserCard({super.key, required this.event});
  final NewUserEvent event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: event.profileId != null
          ? () => context.push(RoutePaths.profile)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _avatarWidget(event.avatarUrl, event.displayName ?? '', cs, 20),
                const Positioned(
                  bottom: -2,
                  right: -4,
                  child: Text('👋', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  children: [
                    TextSpan(
                      text: event.displayName ?? 'Someone',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' joined Dabbler'),
                    if (event.sport != null)
                      TextSpan(
                        text: ' · ${event.sport}',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _ago(event.createdAt),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
