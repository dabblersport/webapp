import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/schema_meta.dart';

abstract class SchemaMetaRepository {
  /// Returns DB-declared meta (or null if table/view absent).
  Future<Result<SchemaMeta?, Failure>> getDbMeta();

  /// Returns DB-declared schema hash (or null).
  Future<Result<String?, Failure>> getDbSchemaHash();

  /// Computes app’s local schema hash from bundled asset (or null if missing).
  Future<Result<String?, Failure>> getAppSchemaHash();

  /// Compares app vs DB; optional allowlist of accepted DB hashes.
  Future<Result<bool, Failure>> isCompatible({
    List<String> acceptedDbHashes = const [],
  });
}
