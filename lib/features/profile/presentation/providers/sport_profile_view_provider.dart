import 'package:flutter/material.dart';
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

class SportProfileViewData {
  const SportProfileViewData({
    required this.metrics,
    required this.activity,
    required this.badges,
    required this.recentEvents,
    this.playerProfile,
    this.playerTier,
    this.organiserProfile,
  });

  final advanced_profile.SportProfile? playerProfile;
  final advanced_tier.SportProfileTier? playerTier;
  final OrganiserProfile? organiserProfile;
  final List<SportProfileMetric> metrics;
  final List<advanced_badge.SportProfileBadge> badges;
  final List<SportProfileEvent> recentEvents;
  final List<SportActivityItem> activity;
}

final sportProfileViewProvider = FutureProvider.autoDispose
    .family<SportProfileViewData, SportProfileRouteArgs>((ref, args) async {
      final sportProfileService = ref.watch(sportProfileServiceProvider);
      final postRepository = ref.watch(postRepositoryProvider);
      final supabase = ref.watch(supabaseProvider);

      advanced_profile.SportProfile? playerProfile;
      advanced_tier.SportProfileTier? playerTier;
      List<advanced_badge.SportProfileBadge> badges =
          const <advanced_badge.SportProfileBadge>[];
      List<SportProfileEvent> recentEvents = const <SportProfileEvent>[];
      OrganiserProfile? organiserProfile;

      if (args.isOrganiserPersona) {
        final organiserRow = await supabase
            .from('organiser')
            .select()
            .eq('profile_id', args.profileId)
            .eq('sport', args.sportKey)
            .maybeSingle();
        if (organiserRow != null) {
          organiserProfile = OrganiserProfile.fromJson(
            Map<String, dynamic>.from(organiserRow as Map),
          );
        }
      } else {
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
            badges = await sportProfileService.getPlayerBadges(
              args.profileId,
              args.sportKey,
            );
          } catch (_) {
            badges = const <advanced_badge.SportProfileBadge>[];
          }
          try {
            playerTier = await sportProfileService.getTierById(
              playerProfile.tierId,
            );
          } catch (_) {
            playerTier = null;
          }
          try {
            recentEvents = await sportProfileService
                .getRecentSportProfileEvents(
                  args.profileId,
                  args.sportKey,
                  limit: 5,
                );
          } catch (_) {
            recentEvents = const <SportProfileEvent>[];
          }
        }
      }

      final authoredPostsResult = await postRepository.getUserPostsBySport(
        profileId: args.profileId,
        sportId: args.sportId,
        limit: 20,
      );
      final commentedPostsResult = await postRepository
          .getCommentedPostsBySport(
            profileId: args.profileId,
            sportId: args.sportId,
            limit: 20,
          );
      final reactedPostsResult = await postRepository.getReactedPostsBySport(
        profileId: args.profileId,
        sportId: args.sportId,
        limit: 20,
      );

      final authoredPosts = authoredPostsResult.fold(
        (_) => const <Post>[],
        (posts) => posts,
      );
      final commentedPosts = commentedPostsResult.fold(
        (_) => const <Post>[],
        (posts) => posts,
      );
      final reactedPosts = reactedPostsResult.fold(
        (_) => const <Post>[],
        (posts) => posts,
      );

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

      addPosts(authoredPosts, SportActivitySource.authored);
      addPosts(commentedPosts, SportActivitySource.commented);
      addPosts(reactedPosts, SportActivitySource.reacted);

      final activity = activityByPostId.values.toList()
        ..sort(
          (left, right) => right.post.createdAt.compareTo(left.post.createdAt),
        );

      final metrics = args.isOrganiserPersona
          ? await _buildOrganiserMetrics(
              supabase: supabase,
              args: args,
              organiserProfile: organiserProfile,
            )
          : _buildPlayerMetrics(playerProfile);

      return SportProfileViewData(
        playerProfile: playerProfile,
        playerTier: playerTier,
        organiserProfile: organiserProfile,
        metrics: metrics,
        badges: badges,
        recentEvents: recentEvents,
        activity: activity,
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

Future<List<SportProfileMetric>> _buildOrganiserMetrics({
  required dynamic supabase,
  required SportProfileRouteArgs args,
  required OrganiserProfile? organiserProfile,
}) async {
  final hostedRows = await supabase
      .from('games')
      .select('id, is_cancelled, start_at')
      .eq('host_user_id', args.userId)
      .eq('sport', args.sportKey);

  final hostedGames = (hostedRows as List).cast<Map<String, dynamic>>();
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
