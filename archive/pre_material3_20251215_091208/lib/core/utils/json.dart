/// Tiny casting helpers for JSON maps coming from Supabase/PostgREST.
library;

T? asT<T>(Object? v) => v is T ? v : null;

String asString(Object? v) {
  if (v == null) return '';
  if (v is String) return v;
  return v.toString();
}

int? asInt(Object? v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? asDouble(Object? v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool? asBool(Object? v) {
  if (v is bool) return v;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  if (v is num) return v != 0;
  return null;
}

DateTime? asDateTime(Object? v) {
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

Map<String, dynamic> asMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val));
  }
  return <String, dynamic>{};
}
