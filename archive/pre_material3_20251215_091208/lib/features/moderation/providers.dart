import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/misc/data/datasources/supabase_remote_data_source.dart';
import '../../data/repositories/moderation_repository.dart';
import '../../data/repositories/moderation_repository_impl.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return ModerationRepositoryImpl(svc);
});
