import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Follows or unfollows [targetProfileId] exactly as the profile screen does
/// (`user_profile_screen.dart` `_toggleFollow`): an insert into the follows
/// table, or the user-level unfollow RPC. Overridable for tests.
typedef MeetupFollowAction =
    Future<void> Function({
      required String myProfileId,
      required String targetProfileId,
      required bool currentlyFollowing,
    });

final meetupFollowActionProvider = Provider<MeetupFollowAction>((ref) {
  return ({
    required String myProfileId,
    required String targetProfileId,
    required bool currentlyFollowing,
  }) async {
    final supabase = Supabase.instance.client;
    if (currentlyFollowing) {
      await supabase.rpc(
        SupabaseConfig.rpcUnfollowUserFn,
        params: {'p_target_profile_id': targetProfileId},
      );
    } else {
      await supabase.from(SupabaseConfig.profileFollowsTable).insert({
        'follower_profile_id': myProfileId,
        'following_profile_id': targetProfileId,
      });
    }
    ref.invalidate(
      isFollowingProvider((
        currentProfileId: myProfileId,
        targetProfileId: targetProfileId,
      )),
    );
    ref.invalidate(followingListProvider(myProfileId));
    ref.invalidate(followingCountProvider(myProfileId));
    ref.invalidate(followersCountProvider(targetProfileId));
  };
});
