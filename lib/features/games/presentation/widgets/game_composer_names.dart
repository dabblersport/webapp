/// The name of a format (sport variant), venue or venue space in the viewer's
/// language (KAN-484): Arabic shows `name_ar` when it is non-empty and falls
/// back to `name_en`; every other language shows `name_en`. The columns are
/// nullable, hence the fallback. Display only: what goes to the server is the
/// ids and `variant_key`, never a name.
String? gameLocalizedName({
  required String languageCode,
  required String? nameEn,
  required String? nameAr,
}) {
  if (languageCode == 'ar') {
    final ar = nameAr?.trim();
    if (ar != null && ar.isNotEmpty) return nameAr;
  }
  return nameEn;
}

/// [gameLocalizedName] for a row read with `name_en` and `name_ar`.
String? gameRowName(Map<String, dynamic>? row, String languageCode) =>
    gameLocalizedName(
      languageCode: languageCode,
      nameEn: row?['name_en'] as String?,
      nameAr: row?['name_ar'] as String?,
    );

/// Whether [query] (already lower-cased) is found in either language of a
/// row's name, so a search typed in Arabic or English finds the row in both.
bool gameRowNameMatches(Map<String, dynamic>? row, String query) {
  for (final key in const <String>['name_en', 'name_ar']) {
    final v = (row?[key] as String?)?.toLowerCase();
    if (v != null && v.contains(query)) return true;
  }
  return false;
}
