import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';

import '../controllers/profile_controller.dart';
import '../controllers/sports_profile_controller.dart';
import 'profile_providers.dart' show getProfileUseCaseProvider;

/// The route identity of a profile someone else is looking at. `userId` is
/// the route slot (not always an auth id); `profileId` pins a persona.
typedef VisitedProfileKey = ({String userId, String? profileId});

/// The visited profile, held per route identity (KAN-688). The visitor
/// screen must never load another account into the global
/// `profileControllerProvider`: that controller is the signed-in user's own
/// identity, read by Home, Create, the join gates and the owner profile.
final visitedProfileControllerProvider = StateNotifierProvider.autoDispose
    .family<ProfileController, ProfileState, VisitedProfileKey>(
      (ref, key) => ProfileController(
        getProfileUseCase: ref.watch(getProfileUseCaseProvider),
      ),
    );

/// The visited profile's sport profiles, scoped like
/// [visitedProfileControllerProvider] so the owner's list is never replaced.
final visitedSportsProfileControllerProvider = StateNotifierProvider.autoDispose
    .family<SportsProfileController, SportsProfileState, VisitedProfileKey>(
      (ref, key) => SportsProfileController(),
    );

/// Followers of a visited profile. Unlike the owner's
/// `followersCountProvider` a failed read is an error, never a 0, so the
/// header can say it does not know.
final visitedFollowersCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, profileId) async {
      final List<dynamic> rows = await Supabase.instance.client
          .from(SupabaseConfig.profileFollowsTable)
          .select('follower_profile_id')
          .eq('following_profile_id', profileId);
      return rows.length;
    });

/// Profiles a visited profile follows; a failed read is an error.
final visitedFollowingCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, profileId) async {
      final List<dynamic> rows = await Supabase.instance.client
          .from(SupabaseConfig.profileFollowsTable)
          .select('following_profile_id')
          .eq('follower_profile_id', profileId);
      return rows.length;
    });

/// The visited profile's own posts: the full count the viewer may read (RLS
/// applies), with the feed's filters. Replaces the length of the first page
/// of 20, which under-counted every author with more than 20 posts.
final visitedPostsCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, profileId) async {
      final List<dynamic> rows = await Supabase.instance.client
          .from(SupabaseConfig.postsTable)
          .select('id')
          .eq('author_profile_id', profileId)
          .eq('is_deleted', false)
          .eq('is_hidden_admin', false)
          .neq('origin_type', 'repost');
      return rows.length;
    });
