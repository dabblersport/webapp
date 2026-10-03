import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

import 'home_post_row.dart';

/// Top-level router — dispatches each sealed [ActiveEvent] variant to its
/// card. Exhaustive: a new variant is a compile error.
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

String _ago(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(dt);
}

/// Players joined a game (`player_joined_game`).
///
/// REMAINING NON-DS USE: the joined players' photos. `DabblerAvatarGroup` takes
/// seeds and an overflow count only, so the group shows the count (design-system
/// team: avatar-group images).
class GroupedJoinCard extends StatelessWidget {
  const GroupedJoinCard({super.key, required this.event});
  final PlayerJoinedEvent event;

  @override
  Widget build(BuildContext context) {
    final int count = event.joinCount;
    final String? gameId = event.gameId;
    return DabblerActivityRow(
      leading: count > 1
          ? DabblerAvatarGroup(overflow: count)
          : const DabblerActivitySystemTile('flash'),
      actor: count > 1 ? '$count players' : 'A player',
      verb: 'joined this game',
      subject: event.gameTitle,
      place: event.venueName,
      when: _ago(event.createdAt),
      sportLabel: event.sport,
      onTap: gameId != null
          ? () => context.push(RoutePaths.gameDetail(gameId))
          : null,
    );
  }
}

/// A game was created (`game_created`), with its "Join Game" action.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.event});
  final GameCreatedEvent event;

  @override
  Widget build(BuildContext context) {
    final String? gameId = event.gameId;
    void open() => context.push(RoutePaths.gameDetail(gameId!));
    return DabblerActivityRow(
      leading: const DabblerActivitySystemTile('game'),
      actor: event.gameTitle ?? 'New Game',
      verb: 'is open',
      place: event.venueName,
      when: _ago(event.createdAt),
      sportLabel: event.sport,
      actionLabel: 'Join Game',
      actionFilled: true,
      onAction: gameId != null ? open : null,
      onTap: gameId != null ? open : null,
    );
  }
}

/// A new post (`post_created`) — the real post, through the Home post row.
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.event});
  final PostCreatedEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postId = event.postId;
    if (postId == null || postId.isEmpty) return const SizedBox.shrink();

    final asyncPost = ref.watch(postDetailProvider(postId));

    return asyncPost.when(
      data: (post) => HomePostRow.resolve(post),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space4),
        child: Center(child: DabblerSpinner(size: DabblerSpinnerSize.sm)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Someone joined Dabbler (`user_joined`).
class NewUserCard extends StatelessWidget {
  const NewUserCard({super.key, required this.event});
  final NewUserEvent event;

  @override
  Widget build(BuildContext context) {
    final String name = event.displayName ?? 'Someone';
    return DabblerActivityRow(
      leading: DabblerAvatar(
        seed: name,
        imageUrl: event.avatarUrl,
        size: DabblerAvatarSize.sm,
      ),
      actor: name,
      verb: 'joined Dabbler',
      subject: event.sport,
      when: _ago(event.createdAt),
      onTap: event.profileId != null
          ? () => context.push(RoutePaths.profile)
          : null,
    );
  }
}
