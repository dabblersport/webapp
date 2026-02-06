import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/data/models/schema_meta.dart';
import '../../data/repositories/schema_meta_repository.dart';
import '../../data/repositories/schema_meta_repository_impl.dart';

final schemaMetaRepositoryProvider = Provider<SchemaMetaRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return SchemaMetaRepositoryImpl(svc);
});

/// Gate: true when app schema hash matches DB schema hash (or is in allowlist).
final schemaCompatibleProvider = FutureProvider<bool>((ref) async {
  final repo = ref.read(schemaMetaRepositoryProvider);
  final res = await repo.isCompatible(
    // For development you can optionally pass allowlisted DB hashes here.
    acceptedDbHashes: const [],
  );
  return res.fold((_) => false, (ok) => ok);
});

/// Expose DB meta for diagnostics/UX.
final dbSchemaMetaProvider = FutureProvider<SchemaMeta?>((ref) async {
  final repo = ref.read(schemaMetaRepositoryProvider);
  final res = await repo.getDbMeta();
  return res.fold((_) => null, (meta) => meta);
});

/// Expose app schema hash for diagnostics/UX.
final appSchemaHashProvider = FutureProvider<String?>((ref) async {
  final repo = ref.read(schemaMetaRepositoryProvider);
  final res = await repo.getAppSchemaHash();
  return res.fold((_) => null, (hash) => hash);
});
