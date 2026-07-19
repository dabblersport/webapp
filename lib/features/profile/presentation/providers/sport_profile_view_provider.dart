import 'package:flutter/material.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/profile/organiser_profile.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/sport_profiles/sport_profile.dart'
    as advanced_profile;
import 'package:dabbler/data/models/sport_profiles/sport_profile_badge.dart'
    as advanced_badge;
import 'package:dabbler/data/models/sport_profiles/sport_profile_event.dart';
import 'package:dabbler/data/models/sport_profiles/sport_profile_tier.dart'
    as advanced_tier;
import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

enum SportActivitySource { authored, commented, reacted }

class SportProfileMetric {
  const SportProfileMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class SportActivityItem {
  const SportActivityItem({required this.post, required this.sources});

  final Post post;
  final Set<SportActivitySource> sources;
}

/// Fast-path data needed to paint the header and scoreboard (1-2 round trips).
class SportProfileCoreData {
  const SportProfileCoreData({
    required this.metrics,
    this.playerProfile,
    this.playerTier,
    this.organiserProfile,
  });

  final advanced_profile.SportProfile? playerProfile;
  final advanced_tier.SportProfileTier? playerTier;
  final OrganiserProfile? organiserProfile;
  final List<SportProfileMetric> metrics;
}

/// Badges + recent events for the Achievements section.
class SportAchievementsData {
  const SportAchievementsData({
    required this.badges,
    required this.recentEvents,
  });

  final List<advanced_badge.SportProfileBadge> badges;
  final List<SportProfileEvent> recentEvents;
}

/// Core sport profile (header + scoreboard). Kept intentionally small so the
/// top of the screen paints without waiting for achievements/posts.
final sportProfileCoreProvider = FutureProvider.autoDispose
    .family<SportProfileCoreData, SportProfileRouteArgs>((ref, args) async {
      final sportProfileService = ref.watch(sportProfileServiceProvider);
      final supabase = ref.watch(supabaseProvider);

      if (args.isOrganiserPersona) {
        // Organiser profile row and hosted-games rows are independent —
        // start both requests before awaiting either so they run in parallel.
        final Future<dynamic> organiserRowFuture = supabase
            .from(SupabaseConfig.organiserTable)
            .select()
            .eq('profile_id', args.profileId)
            .eq('sport', args.sportKey)
            .maybeSingle()
            .then<dynamic>((row) => row);
        final hostedGamesFuture = _fetchHostedGameRows(
          supabase: supabase,
          args: args,
        );

        final organiserRow = await organiserRowFuture;
        final hostedGames = await hostedGamesFuture;

        final organiserProfile = organiserRow == null
            ? null
            : OrganiserProfile.fromJson(
                Map<String, dynamic>.from(organiserRow as Map),
              );

        return SportProfileCoreData(
          organiserProfile: organiserProfile,
          metrics: _buildOrganiserMetricsFrom(
            hostedGames: hostedGames,
            organiserProfile: organiserProfile,
          ),
        );
      }

      advanced_profile.SportProfile? playerProfile;
      advanced_tier.SportProfileTier? playerTier;
      try {
        playerProfile = await sportProfileService.getSportProfile(
          args.profileId,
          args.sportKey,
        );
      } catch (_) {
        playerProfile = null;
      }

      if (playerProfile != null) {
        try {
          playerTier = await sportProfileService.getTierById(
            playerProfile.tierId,
          );
        } catch (_) {
          playerTier = null;
        }
      }

      return SportProfileCoreData(
        playerProfile: playerProfile,
        playerTier: playerTier,
        metrics: _buildPlayerMetrics(playerProfile),
      );
    });

/// Badges + recent events (player personas only), fetched in parallel after
/// the core profile resolves.
final sportAchievementsProvider = FutureProvider.autoDispose
    .family<SportAchievementsData, SportProfileRouteArgs>((ref, args) async {
      const empty = SportAchievementsData(
        badges: <advanced_badge.SportProfileBadge>[],
        recentEvents: <SportProfileEvent>[],
      );
      if (args.isOrganiserPersona) {
        return empty;
      }

      final core = await ref.watch(sportProfileCoreProvider(args).future);
      if (core.playerProfile == null) {
        return empty;
      }

      final sportProfileService = ref.watch(sportProfileServiceProvider);
      final results = await Future.wait([
        sportProfileService
            .getPlayerBadges(args.profileId, args.sportKey)
            .catchError((_) => const <advanced_badge.SportProfileBadge>[]),
        sportProfileService
            .getRecentSportProfileEvents(args.profileId, args.sportKey, limit: 5)
            .catchError((_) => const <SportProfileEvent>[]),
      ]);

      return SportAchievementsData(
        badges: results[0] as List<advanced_badge.SportProfileBadge>,
        recentEvents: results[1] as List<SportProfileEvent>,
      );
    });

/// Sport-tagged social activity (authored/commented/reacted posts), fetched
/// in parallel and merged.
final sportActivityProvider = FutureProvider.autoDispose
    .family<List<SportActivityItem>, SportProfileRouteArgs>((ref, args) async {
      final postRepository = ref.watch(postRepositoryProvider);

      final results = await Future.wait([
        postRepository.getUserPostsBySport(
          profileId: args.profileId,
          sportId: args.sportId,
          limit: 20,
        ),
        postRepository.getCommentedPostsBySport(
          profileId: args.profileId,
          sportId: args.sportId,
          limit: 20,
        ),
        postRepository.getReactedPostsBySport(
          profileId: args.profileId,
          sportId: args.sportId,
          limit: 20,
        ),
      ]);

      List<Post> unwrap(int index) =>
          results[index].fold((_) => const <Post>[], (posts) => posts);

      final activityByPostId = <String, SportActivityItem>{};

      void addPosts(List<Post> posts, SportActivitySource source) {
        for (final post in posts) {
          final existing = activityByPostId[post.id];
          if (existing == null) {
            activityByPostId[post.id] = SportActivityItem(
              post: post,
              sources: {source},
            );
            continue;
          }
          activityByPostId[post.id] = SportActivityItem(
            post: existing.post,
            sources: {...existing.sources, source},
          );
        }
      }

      addPosts(unwrap(0), SportActivitySource.authored);
      addPosts(unwrap(1), SportActivitySource.commented);
      addPosts(unwrap(2), SportActivitySource.reacted);

      return activityByPostId.values.toList()
        ..sort(
          (left, right) => right.post.createdAt.compareTo(left.post.createdAt),
        );
    });

List<SportProfileMetric> _buildPlayerMetrics(
  advanced_profile.SportProfile? profile,
) {
  if (profile == null) {
    return const <SportProfileMetric>[];
  }

  final averageRating = profile.ratingCount <= 0
      ? 0.0
      : profile.ratingTotal / profile.ratingCount;

  return <SportProfileMetric>[
    SportProfileMetric(
      label: 'Matches',
      value: profile.matchesPlayed.toString(),
      icon: Icons.sports_score,
    ),
    SportProfileMetric(
      label: 'Rating',
      value: averageRating.toStringAsFixed(1),
      icon: Icons.star_outline,
    ),
    SportProfileMetric(
      label: 'Form',
      value: profile.formScore.toStringAsFixed(1),
      icon: Icons.trending_up,
    ),
    SportProfileMetric(
      label: 'Reliability',
      value: profile.reliabilityScore.toStringAsFixed(0),
      icon: Icons.verified_outlined,
    ),
  ];
}

Future<List<Map<String, dynamic>>> _fetchHostedGameRows({
  required dynamic supabase,
  required SportProfileRouteArgs args,
}) async {
  final hostedRows = await supabase
      .from(SupabaseConfig.gamesTable)
      .select('id, is_cancelled, start_at')
      .eq('creator_user_id', args.userId)
      .eq('sport_id', args.sportId);
  return (hostedRows as List).cast<Map<String, dynamic>>();
}

List<SportProfileMetric> _buildOrganiserMetricsFrom({
  required List<Map<String, dynamic>> hostedGames,
  required OrganiserProfile? organiserProfile,
}) {
  final totalHosted = hostedGames.length;
  final activeHosted = hostedGames
      .where((game) => game['is_cancelled'] != true)
      .length;
  final upcomingHosted = hostedGames.where((game) {
    final startAtRaw = game['start_at'];
    final startAt = startAtRaw is String ? DateTime.tryParse(startAtRaw) : null;
    if (startAt == null) {
      return false;
    }
    return startAt.isAfter(DateTime.now()) && game['is_cancelled'] != true;
  }).length;

  return <SportProfileMetric>[
    SportProfileMetric(
      label: 'Hosted',
      value: totalHosted.toString(),
      icon: Icons.event_available_outlined,
    ),
    SportProfileMetric(
      label: 'Upcoming',
      value: upcomingHosted.toString(),
      icon: Icons.schedule_outlined,
    ),
    SportProfileMetric(
      label: 'Level',
      value: (organiserProfile?.organiserLevel ?? 0).toString(),
      icon: Icons.leaderboard_outlined,
    ),
    SportProfileMetric(
      label: 'Active',
      value: activeHosted.toString(),
      icon: Icons.check_circle_outline,
    ),
  ];
}
