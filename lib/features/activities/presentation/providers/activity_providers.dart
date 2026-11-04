import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/activity_feed_datasource.dart';
import '../../data/datasources/activity_analytics_datasource.dart';
import '../controllers/activity_feed_controller.dart';
import '../controllers/activity_log_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show myProfileIdProvider;
import 'package:dabbler/features/social/providers/public_activity_providers.dart'
    show publicActivityRepositoryProvider;

/// Provides the Supabase client instance.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provides the ActivityFeedDatasource.
final activityFeedDatasourceProvider = Provider<ActivityFeedDatasource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ActivityFeedDatasource(supabase);
});

/// Provides the ActivityAnalyticsDatasource.
final activityAnalyticsDatasourceProvider =
    Provider<ActivityAnalyticsDatasource>((ref) {
      final supabase = ref.watch(supabaseClientProvider);
      return ActivityAnalyticsDatasource(supabase);
    });

/// Provides the ActivityFeedController.
final activityFeedControllerProvider =
    StateNotifierProvider<ActivityFeedController, ActivityFeedState>((ref) {
      final datasource = ref.watch(activityFeedDatasourceProvider);
      return ActivityFeedController(datasource);
    });

/// KAN-852: the Home bell → Activity log. Merges the personal RPC log with the
/// owner's own `public_activities` (what the owner's Profile → Activity tab
/// used to show) through their existing authenticated reads.
final activityLogControllerProvider =
    StateNotifierProvider<ActivityLogController, ActivityLogState>((ref) {
      return ActivityLogController(
        feed: ref.watch(activityFeedDatasourceProvider),
        social: ref.watch(publicActivityRepositoryProvider),
        profileId: () => ref.read(myProfileIdProvider.future),
      );
    });
