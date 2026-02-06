import 'package:meta/meta.dart';

@immutable
class SchemaMeta {
  final String? schemaHash; // e.g., sha256 of DB canonical schema
  final int? dbVersion; // optional integer version
  final String? appMinVersion; // optional minimum client version
  final DateTime? updatedAt; // when DB meta last updated
  final String? notes; // free-form

  const SchemaMeta({
    required this.schemaHash,
    required this.dbVersion,
    required this.appMinVersion,
    required this.updatedAt,
    required this.notes,
  });

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory SchemaMeta.fromMap(Map<String, dynamic> m) => SchemaMeta(
    schemaHash:
        (m['schema_hash'] ?? m['hash'] ?? m['fingerprint'] ?? m['value'])
            ?.toString(),
    dbVersion: m['db_version'] is num
        ? (m['db_version'] as num).toInt()
        : int.tryParse('${m['db_version']}'),
    appMinVersion: m['app_min_version']?.toString(),
    updatedAt: _dt(m['updated_at']),
    notes: m['notes']?.toString(),
  );

  Map<String, dynamic> toMap() => {
    'schema_hash': schemaHash,
    'db_version': dbVersion,
    'app_min_version': appMinVersion,
    'updated_at': updatedAt?.toIso8601String(),
    'notes': notes,
  };
}
