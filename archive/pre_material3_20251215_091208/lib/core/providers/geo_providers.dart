import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/repositories/geo_repository.dart';
import 'package:dabbler/data/repositories/geo_repository_impl.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';

/// Provides access to the geo-aware venue repository backed by Supabase.
final geoRepositoryProvider = Provider<GeoRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return GeoRepositoryImpl(svc);
});
