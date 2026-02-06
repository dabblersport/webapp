import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/profile_repository.dart';
import '../repositories/profile_stats_repository.dart';

/// Profile repository provider
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(); // Placeholder implementation
});

/// Profile stats repository provider
final profileStatsRepositoryProvider = Provider<ProfileStatsRepository>((ref) {
  return ProfileStatsRepository(); // Placeholder implementation
});
