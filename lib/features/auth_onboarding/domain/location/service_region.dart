/// The app's service region (KAN-584): account-level and explicitly chosen by
/// the user. KAN-640 R6: with nothing saved, the first screen preselects the
/// country detected once from the IP (Global when unsupported or on failure); a
/// manual choice always wins. Never inferred from VPN or device locale.
/// Separate from the public profile country and from the device's current
/// location.
library;

const String kGlobalRegion = 'Global';

/// The supported countries, by the English name the app stores.
const List<String> kServiceCountries = <String>[
  'Egypt',
  'Morocco',
  'Qatar',
  'Saudi Arabia',
  'United Arab Emirates',
];

/// A supported region name in its canonical spelling, or [kGlobalRegion] for
/// anything else (null, empty, "United Kingdom", a device-locale country).
String normalizeServiceRegion(String? value) {
  final String v = (value ?? '').trim().toLowerCase();
  for (final String c in kServiceCountries) {
    if (c.toLowerCase() == v) return c;
  }
  return kGlobalRegion;
}

/// The one ordering policy for both languages: the countries sorted by their
/// localized name (Arabic ignoring the definite article and alef variants),
/// then Global as the explicit last option.
List<String> orderedServiceRegions(
  String languageCode,
  String Function(String canonical) localizedName,
) {
  final List<String> countries = List<String>.of(kServiceCountries)
    ..sort(
      (String a, String b) => _sortKey(
        localizedName(a),
        languageCode,
      ).compareTo(_sortKey(localizedName(b), languageCode)),
    );
  return <String>[...countries, kGlobalRegion];
}

String _sortKey(String name, String languageCode) {
  var s = name.trim();
  if (languageCode == 'ar') {
    s = s.replaceAll(RegExp('[أإآ]'), 'ا').replaceFirst(RegExp('^ال'), '');
    return s;
  }
  return s.toLowerCase();
}
