import 'dart:convert';
import 'package:dabbler/core/fp/failure.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:meta/meta.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import '../models/schema_meta.dart';
import 'base_repository.dart';
import 'schema_meta_repository.dart';

@immutable
class SchemaMetaRepositoryImpl extends BaseRepository
    implements SchemaMetaRepository {
  static const _table = 'schema_meta';
  static const _assetPath = 'supabase/schema/schema.json';

  const SchemaMetaRepositoryImpl(super.svc);

  @override
  Future<Result<SchemaMeta?, Failure>> getDbMeta() {
    return guard<SchemaMeta?>(() async {
      final row = await svc.client
          .from(_table)
          .select('*')
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      return SchemaMeta.fromMap(asMap(row));
    });
  }

  @override
  Future<Result<String?, Failure>> getDbSchemaHash() async {
    final meta = await getDbMeta();
    return meta.map((m) => m?.schemaHash);
  }

  @override
  Future<Result<String?, Failure>> getAppSchemaHash() {
    return guard<String?>(() async {
      final raw = await _loadAsset();
      if (raw == null || raw.trim().isEmpty) return null;

      try {
        final decoded = json.decode(raw);
        final normalized = json.encode(decoded);
        return _sha256(normalized);
      } catch (_) {
        return _sha256(raw);
      }
    });
  }

  @override
  Future<Result<bool, Failure>> isCompatible({
    List<String> acceptedDbHashes = const [],
  }) {
    return guard<bool>(() async {
      final appHashRes = await getAppSchemaHash();
      final appHash = appHashRes.match(
        (failure) => throw failure,
        (value) => value,
      );

      final dbHashRes = await getDbSchemaHash();
      final dbHash = dbHashRes.match(
        (failure) => throw failure,
        (value) => value,
      );

      if (appHash == null || dbHash == null) return false;
      if (appHash == dbHash) return true;
      if (acceptedDbHashes.contains(dbHash)) return true;
      return false;
    });
  }

  Future<String?> _loadAsset() async {
    try {
      return await rootBundle.loadString(_assetPath);
    } on Exception {
      return null;
    }
  }

  String _sha256(String value) {
    final bytes = utf8.encode(value);
    return sha256.convert(bytes).toString();
  }
}
