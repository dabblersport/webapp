import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/avatar_url_resolver.dart';

class DefaultAvatarService {
  DefaultAvatarService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String buildSeed({required String userId, required String profileId}) {
    return 'profile:$profileId:user:$userId';
  }

  String buildAvatarReference({
    required String userId,
    required String profileId,
  }) {
    return buildDsAvatarReference(
      buildSeed(userId: userId, profileId: profileId),
    );
  }

  Future<String> ensureProfileAvatar({
    required String userId,
    required String profileId,
    String? currentAvatarUrl,
  }) async {
    final existing = currentAvatarUrl?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final avatarReference = buildAvatarReference(
      userId: userId,
      profileId: profileId,
    );

    await _client
        .from(SupabaseConfig.usersTable)
        .update({
          'avatar_url': avatarReference,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', profileId)
        .eq('user_id', userId);

    return avatarReference;
  }
}
