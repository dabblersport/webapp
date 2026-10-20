import 'package:dabbler/features/auth_onboarding/domain/location/service_region.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The localized name of a service region (canonical English name in).
String serviceRegionLabel(AppLocalizations l, String canonical) =>
    switch (normalizeServiceRegion(canonical)) {
      'Egypt' => l.region_country_Egypt,
      'Morocco' => l.region_country_Morocco,
      'Qatar' => l.region_country_Qatar,
      'Saudi Arabia' => l.region_country_KSA,
      'United Arab Emirates' => l.region_country_UAE,
      _ => l.region_country_Global,
    };

/// The options every region selector shows, in the one ordering policy:
/// (canonical name, localized label).
List<(String, String)> serviceRegionOptions(AppLocalizations l, String lang) {
  return <(String, String)>[
    for (final String c in orderedServiceRegions(
      lang,
      (String canonical) => serviceRegionLabel(l, canonical),
    ))
      (c, serviceRegionLabel(l, c)),
  ];
}
