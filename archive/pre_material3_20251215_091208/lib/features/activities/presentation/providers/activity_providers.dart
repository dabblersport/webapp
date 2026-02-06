import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/activity_feed_datasource.dart';
import '../../data/datasources/activity_analytics_datasource.dart';
import '../controllers/activity_feed_controller.dart';

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
