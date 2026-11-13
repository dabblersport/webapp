/// KAN-927: the one place a timestamp crosses the wire.
///
/// Postgres `timestamptz` columns come back as UTC strings (`...+00:00`), and
/// `DateTime.parse` keeps them in UTC, so `.hour` and `DateFormat` show UTC.
/// Every read goes through [parseInstantLocal] so the app holds the viewer's
/// local time, and every write goes through [toWireInstant] so a picked local
/// time is sent as the matching UTC instant (a naive `toIso8601String()` of a
/// local DateTime carries no offset and Postgres reads it as UTC).
library;

import 'package:json_annotation/json_annotation.dart';

/// Parses a server timestamp into the viewer's local time. Null on null,
/// empty or unparseable input. A [DateTime] passes through as local.
DateTime? parseInstantLocal(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toLocal();
  final s = raw.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}

/// The UTC ISO-8601 string to send for [value] (local or UTC).
String toWireInstant(DateTime value) => value.toUtc().toIso8601String();

/// Nullable form of [toWireInstant].
String? toWireInstantOrNull(DateTime? value) =>
    value == null ? null : toWireInstant(value);

/// json_serializable converter for a required timestamptz field.
class LocalInstantConverter implements JsonConverter<DateTime, String> {
  const LocalInstantConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json).toLocal();

  @override
  String toJson(DateTime object) => toWireInstant(object);
}

/// json_serializable converter for a nullable timestamptz field.
class LocalInstantOrNullConverter implements JsonConverter<DateTime?, String?> {
  const LocalInstantOrNullConverter();

  @override
  DateTime? fromJson(String? json) => parseInstantLocal(json);

  @override
  String? toJson(DateTime? object) => toWireInstantOrNull(object);
}
