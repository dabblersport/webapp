import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/providers/mapbox_geocode_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// KAN-587: the map-service results of a City / Area search, as flat rows.
/// Loading shows a spinner; a failed request shows the error with a Retry
/// (never "no results"); an empty answer shows the empty state.
class MapPlaceResults extends ConsumerWidget {
  const MapPlaceResults.cities({
    super.key,
    required String query,
    required this.onPick,
  }) : _cityQuery = query,
       _areaQuery = null,
       _countryCityQuery = null;

  const MapPlaceResults.areas({
    super.key,
    required AreaQuery query,
    required this.onPick,
  }) : _areaQuery = query,
       _cityQuery = null,
       _countryCityQuery = null;

  /// KAN-640: cities of one country only.
  const MapPlaceResults.countryCities({
    super.key,
    required CountryCityQuery query,
    required this.onPick,
  }) : _countryCityQuery = query,
       _cityQuery = null,
       _areaQuery = null;

  final String? _cityQuery;
  final AreaQuery? _areaQuery;
  final CountryCityQuery? _countryCityQuery;
  final void Function(MapboxPlace place) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final AsyncValue<List<MapboxPlace>> results = _cityQuery != null
        ? ref.watch(mapboxCityProvider(_cityQuery))
        : _countryCityQuery != null
        ? ref.watch(mapboxCountryCityProvider(_countryCityQuery))
        : ref.watch(mapboxAreaProvider(_areaQuery!));
    return results.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(DabblerSpacing.space8),
        child: Center(child: DabblerSpinner()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space8),
        child: DabblerEmptyState.error(
          title: l.game_error_generic,
          size: DabblerEmptyStateSize.inline,
          retryLabel: l.feed_retry,
          onRetry: () => _cityQuery != null
              ? ref.invalidate(mapboxCityProvider(_cityQuery))
              : _countryCityQuery != null
              ? ref.invalidate(mapboxCountryCityProvider(_countryCityQuery))
              : ref.invalidate(mapboxAreaProvider(_areaQuery!)),
        ),
      ),
      data: (List<MapboxPlace> places) => places.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(DabblerSpacing.space8),
              child: DabblerEmptyState(
                icon: 'location-slash',
                title: l.manual_location_empty_title,
                text: l.manual_location_empty_text,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final MapboxPlace place in places) ...<Widget>[
                  DabblerInputRow(
                    flat: true,
                    onTap: () => onPick(place),
                    leading: const DabblerIcon(
                      'location',
                      size: DabblerSizing.iconRow,
                    ),
                    title: place.name,
                    subtitle: place.fullAddress,
                    trailing: const DabblerChevron(),
                    semanticLabel: place.fullAddress,
                  ),
                  const DabblerGap.v(DabblerSpacing.space2),
                ],
              ],
            ),
    );
  }
}
