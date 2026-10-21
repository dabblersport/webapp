import 'dart:async';

import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/presentation/widgets/map_place_results.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_header.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The page-local City filter. It starts from the device's city and changing
/// it re-queries this page only: nothing here writes the device location,
/// saved places, the service region or the public profile. Cities come from the
/// map service (the same search the location setup uses), not a constant list.
class SportCityBar extends ConsumerWidget {
  const SportCityBar({super.key, required this.sportId});

  final String sportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<SportPageCity> city = ref.watch(
      sportPageCityProvider(sportId),
    );
    final SportPageCity? value = city.valueOrNull;
    if (value == null) return const SizedBox.shrink();

    if (value.isNone) {
      return Padding(
        padding: kSportGutter,
        child: DabblerEmptyState(
          icon: 'location',
          title: l.sport_overview_city_cta_title,
          text: l.sport_overview_city_cta_text,
          size: DabblerEmptyStateSize.inline,
          action: DabblerButton(
            label: l.sport_overview_city_cta_button,
            onPressed: () => _pick(context, ref),
          ),
        ),
      );
    }
    return Padding(
      padding: kSportGutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DabblerChip(
                label: value.name!,
                selected: true,
                leadingIcon: const DabblerIcon(
                  'location',
                  size: DabblerSizing.iconInline,
                ),
                onTap: () => _pick(context, ref),
              ),
              const DabblerGap.h(DabblerSpacing.space2),
              DabblerButton(
                label: l.sport_overview_city_clear,
                tone: DabblerButtonTone.text,
                size: DabblerButtonSize.small,
                onPressed: () =>
                    ref
                        .read(sportPageCityOverrideProvider(sportId).notifier)
                        .state = SportPageCity
                        .none,
              ),
            ],
          ),
          if (!value.isMapped) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space2),
            DabblerText(
              l.sport_overview_city_unmapped(value.name!),
              style: DabblerType.caption1,
              tone: DabblerTextTone.secondary,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final MapboxPlace? place = await showAppSheet<MapboxPlace>(
      context: context,
      title: AppLocalizations.of(context).sport_overview_city_pick_title,
      detent: DabblerSheetDetent.content,
      builder: (_) => const _CityPickSheet(),
    );
    if (place == null) return;
    final SportPageCity chosen = await resolveSportCity(
      ref.read(sportOverviewRepositoryProvider),
      place.name,
    );
    ref.read(sportPageCityOverrideProvider(sportId).notifier).state = chosen;
  }
}

/// The city search of the location setup, without its commit: it returns the
/// chosen place and writes nothing.
class _CityPickSheet extends StatefulWidget {
  const _CityPickSheet();

  @override
  State<_CityPickSheet> createState() => _CityPickSheetState();
}

class _CityPickSheetState extends State<_CityPickSheet> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final String q = _search.text.trim();
    if (q.length < 2) {
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(DabblerMotion.debounceSearch, () {
      if (mounted) setState(() => _query = q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DabblerSearchField(
          controller: _search,
          placeholder: l.manual_location_search_placeholder,
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        if (_query.isNotEmpty)
          MapPlaceResults.cities(
            query: _query,
            onPick: (MapboxPlace place) => Navigator.of(context).pop(place),
          ),
      ],
    );
  }
}
