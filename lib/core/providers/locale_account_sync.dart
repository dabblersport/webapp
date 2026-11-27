import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The language saved on the signed-in account (`profiles.language`) and the
/// profile row it came from.
typedef SavedLanguage = ({String profileId, String? language});

/// Reads the account's saved language. Overridable in tests.
final savedLanguageLoaderProvider =
    Provider<Future<Result<SavedLanguage?, Failure>> Function(String userId)>(
      (ref) =>
          (String userId) => Result.guard(() async {
            final row = await Supabase.instance.client
                .from(SupabaseConfig.usersTable)
                .select('id, language')
                .eq('user_id', userId)
                .eq('is_active', true)
                .order('created_at', ascending: true)
                .limit(1)
                .maybeSingle();
            if (row == null) return null;
            return (
              profileId: row['id'] as String,
              language: row['language'] as String?,
            );
          }, (e) => Failure.from(e)),
    );

/// KAN-1058: the one place the saved language reaches the app locale.
///
/// Watched by the app root, so it runs at start and on every sign-in, before
/// any screen loads the full profile. Without it the locale stayed on the
/// device language until the Profile screen loaded the profile, so Feeds (the
/// first tab) rendered English for an Arabic account.
final localeAccountSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(cacheAccountIdProvider);
  if (userId == null) return;
  final load = ref.read(savedLanguageLoaderProvider);
  var disposed = false;
  ref.onDispose(() => disposed = true);
  load(userId).then((result) {
    if (disposed) return;
    if (!result.isSuccess) return;
    final saved = result.requireValue;
    if (saved == null) return;
    ref
        .read(localeProvider.notifier)
        .hydrateFromLanguage(saved.language, profileId: saved.profileId);
  });
});
