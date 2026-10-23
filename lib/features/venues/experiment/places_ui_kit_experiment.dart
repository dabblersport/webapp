import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../core/config/feature_flags.dart';

/// KAN-629: isolated Places UI Kit cover experiment.
///
/// This file is the whole Flutter side of the experiment. With
/// [FeatureFlags.placesUiKitExperiment] off (the default) [experimentCover]
/// returns the baseline cover untouched and nothing here touches a native
/// SDK, a counter or the network.
///
/// The native Places UI Kit host is not part of this branch yet: it needs an
/// owner-approved Google Cloud project and restricted keys (see
/// docs/experiments/KAN-629-places-ui-kit.md). [PlacesUiKitHost] is the seam
/// the native platform view will implement; until one is registered every
/// card keeps its baseline cover.
class PlacesExperimentVenue {
  const PlacesExperimentVenue(this.venueId, this.name);

  final String venueId;
  final String name;
}

/// The nine venues of the experiment, by canonical Supabase id.
const List<PlacesExperimentVenue> kPlacesExperimentVenues = [
  PlacesExperimentVenue(
    'b53aea46-f61e-4d81-9de7-9ca515f0b9f9',
    'All Star Sport',
  ),
  PlacesExperimentVenue(
    '608c44d5-0d3e-4f9f-ace3-a9e7bf565dc4',
    'Champs Sports Club (Al Quoz)',
  ),
  PlacesExperimentVenue('85de82d7-9470-408c-ba3d-3559ea9248b6', 'Aktiv Nation'),
  PlacesExperimentVenue(
    'c68d6c80-54a4-4d17-ac93-395be1fa8ba4',
    'Ahdaaf Sports Club',
  ),
  PlacesExperimentVenue(
    '387f6a70-760b-47d5-a991-495d07aa869f',
    'ISD Dubai Sports City',
  ),
  PlacesExperimentVenue(
    'c5aefd96-474d-4171-b7e6-64155a1d6fa3',
    'United Pro Sports',
  ),
  PlacesExperimentVenue(
    '069a13d4-8994-462c-9226-0024d1d4006c',
    '365 Open Sports',
  ),
  PlacesExperimentVenue(
    'e91d8b43-360f-4da6-ad0b-d89b5402db85',
    'Jebel Ali Recreation Club',
  ),
  PlacesExperimentVenue(
    'cbcb52c5-9ffd-42e3-bec3-a3447a18cf3f',
    'Danube Sports World',
  ),
];

/// Hard ceiling on Google request/load attempts for the whole experiment
/// (ticket section 9). Matching attempts count against the same ceiling.
const int kPlacesAttemptCeiling = 2000;

/// Counts attempts before they are made. An app counter does not guarantee
/// no charge (budget alerts and quotas still apply); it is the conservative
/// guard the ticket asks for. The native host reserves one attempt per
/// actual component load, never per Flutter rebuild.
class PlacesAttemptGuard {
  PlacesAttemptGuard({this.ceiling = kPlacesAttemptCeiling, int used = 0})
    : _used = used;

  final int ceiling;
  int _used;

  int get used => _used;
  int get remaining => ceiling - _used;

  /// Reserves one attempt. False once the ceiling is reached, and nothing is
  /// counted then.
  bool tryReserve() {
    if (_used >= ceiling) return false;
    _used++;
    return true;
  }
}

/// Seam for the native Places UI Kit platform view. Implemented by the
/// native integration once credentials exist; absent today.
abstract class PlacesUiKitHost {
  /// A widget that loads [placeId] inside the existing cover slot, or null
  /// when this host cannot show it. The host reserves an attempt on
  /// [PlacesExperiment.guard] before each real load.
  Widget? buildCover(String placeId, {required double height});
}

/// Experiment-only manifest of confirmed Google Place IDs by Supabase id.
/// Empty until Phase B (matching) runs; Place IDs may be retained, other
/// Google content may not.
const Map<String, String> kPlacesManifest = <String, String>{};

class PlacesExperiment {
  PlacesExperiment._();

  static PlacesUiKitHost? host;
  static PlacesAttemptGuard guard = PlacesAttemptGuard();
  static Map<String, String> manifest = kPlacesManifest;

  @visibleForTesting
  static void reset() {
    host = null;
    guard = PlacesAttemptGuard();
    manifest = kPlacesManifest;
  }

  static bool isAllowlisted(String venueId) =>
      kPlacesExperimentVenues.any((v) => v.venueId == venueId);
}

/// Returns the cover for [venueId]: [baseline] unless the experiment is on,
/// the platform is Android or iOS, the venue is one of the nine, a Place ID
/// is confirmed, a host is registered and the attempt budget is not spent.
Widget experimentCover({
  required String venueId,
  required Widget baseline,
  required double height,
  bool? enabled,
  TargetPlatform? platform,
  bool? isWeb,
}) {
  if (!(enabled ?? FeatureFlags.placesUiKitExperiment)) return baseline;
  if (isWeb ?? kIsWeb) return baseline;
  final p = platform ?? defaultTargetPlatform;
  if (p != TargetPlatform.android && p != TargetPlatform.iOS) return baseline;
  if (!PlacesExperiment.isAllowlisted(venueId)) return baseline;
  final placeId = PlacesExperiment.manifest[venueId];
  final host = PlacesExperiment.host;
  if (placeId == null || host == null) return baseline;
  if (PlacesExperiment.guard.remaining <= 0) return baseline;
  return host.buildCover(placeId, height: height) ?? baseline;
}
