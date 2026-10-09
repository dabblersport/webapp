// Composer-only, pure Dart: picks the display name for a catalogue row
// (format, venue, space) by the current locale (KAN-484).

/// Arabic: [nameAr] when it is non-empty after trim, else [nameEn].
/// English: [nameEn], else [nameAr].
/// When both are null or blank, returns ''.
String localizedName({
  required String? nameEn,
  required String? nameAr,
  required bool arabic,
}) {
  final en = nameEn?.trim() ?? '';
  final ar = nameAr?.trim() ?? '';
  if (arabic) return ar.isNotEmpty ? ar : en;
  return en.isNotEmpty ? en : ar;
}

/// [localizedName] keyed by a language code (`'ar'` is Arabic).
String localizedNameFor(
  String languageCode, {
  required String? nameEn,
  required String? nameAr,
}) =>
    localizedName(nameEn: nameEn, nameAr: nameAr, arabic: languageCode == 'ar');

/// [localizedNameFor] over a row carrying `name_en` / `name_ar`.
String localizedRowName(Map<String, dynamic> row, String languageCode) =>
    localizedNameFor(
      languageCode,
      nameEn: row['name_en'] as String?,
      nameAr: row['name_ar'] as String?,
    );

/// True when [query] matches either name: case-insensitive for Latin,
/// plain contains for Arabic.
bool namesMatch(String query, Iterable<String?> names) {
  final q = query.toLowerCase();
  return names.any((n) => n != null && n.toLowerCase().contains(q));
}
