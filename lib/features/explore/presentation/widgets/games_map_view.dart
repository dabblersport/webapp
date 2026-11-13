import 'package:dabbler/core/maps/dabbler_map.dart';
import 'package:dabbler/core/maps/map_config.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

/// KAN-669: Games discovery shows a list (default) or a map.
final gamesMapModeProvider = StateProvider<bool>((ref) => false);

/// Whether [g] earns a pin: an upcoming, public, located game. Past, cancelled
/// and private games never do.
bool isMappableGame(NearbyGameModel g, DateTime now) {
  if (!g.isPublic) return false;
  if (g.status == 'ended' || g.status == 'cancelled') return false;
  final DateTime? at = g.scheduledAt;
  if (at == null || !at.isAfter(now)) return false;
  return g.latitude != null && g.longitude != null;
}

/// One pin per game in [games] that [isMappableGame].
List<DabblerMapMarker> gameMapMarkers(
  Iterable<NearbyGameModel> games,
  DateTime now,
) => <DabblerMapMarker>[
  for (final NearbyGameModel g in games)
    if (isMappableGame(g, now))
      DabblerMapMarker(
        id: g.id,
        point: LatLng(g.latitude!, g.longitude!),
        icon: 'game',
      ),
];

/// The map body of Games discovery. [games] are already filtered like the
/// list; a pin tap opens the same game card the list opens, and the map stays
/// mounted underneath so back returns to it at the same position.
class GamesMapView extends ConsumerWidget {
  const GamesMapView({super.key, required this.games});

  final List<NearbyGameModel> games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<DabblerMapMarker> markers = gameMapMarkers(
      games,
      DateTime.now(),
    );
    final Future<void> Function(BuildContext) openDrawer = ref.read(
      mapSetLocationOpenerProvider,
    );
    return ProviderScope(
      overrides: [
        // The screen already opens the drawer once when location is denied.
        mapSetLocationOpenerProvider.overrideWithValue((BuildContext c) async {
          final bool denied =
              ref.read(activeLocationProvider).valueOrNull
                  is ActiveLocationDenied;
          if (!denied) await openDrawer(c);
        }),
      ],
      child: Column(
        children: [
          if (markers.isEmpty)
            Expanded(
              child: ListingEmpty(
                icon: 'game',
                title: l.games_map_empty_title,
                text: l.games_map_empty_text,
              ),
            ),
          Expanded(
            flex: 2,
            child: DabblerMap(
              markers: markers,
              onMarkerTap: (DabblerMapMarker m) =>
                  context.push(RoutePaths.gameDetail(m.id)),
            ),
          ),
        ],
      ),
    );
  }
}
