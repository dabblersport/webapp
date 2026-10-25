import 'dart:async';

import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/presentation/widgets/map_place_results.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The page-local City choice (the "Choose city" drawer of Sport Overview v2).
/// It starts from the device's city and changing it re-queries this page only:
/// nothing here writes the device location, saved places, the service region
/// or the public profile. Cities come from the map service (the same search
/// the location setup uses), not a constant list, so the design's per-city
/// "venues · games this week" counts are not drawn: the data has no such
/// per-city summary (recorded on KAN-591).
Future<void> pickSportCity(
  BuildContext context,
  WidgetRef ref,
  String sportId,
) async {
  final AppLocalizations l = AppLocalizations.of(context);
  // Awaited, not peeked: once a city is chosen nothing watches the (auto
  // disposed) device city, and a peek would find it empty.
  final String? deviceCity = await ref
      .read(sportDeviceCityProvider.future)
      .then<String?>((SportPageCity c) => c.name)
      .catchError((Object _) => null);
  if (!context.mounted) return;
  final Object? choice = await showAppSheet<Object>(
    context: context,
    title: l.listing_choose_city_title,
    detent: DabblerSheetDetent.content,
    builder: (_) => _CitySheet(deviceCity: deviceCity),
  );
  if (choice == null) return;
  final StateController<SportPageCity?> override = ref.read(
    sportPageCityOverrideProvider(sportId).notifier,
  );
  if (choice is _UseDevice) {
    // The device's own city again: no page-level choice.
    override.state = null;
    return;
  }
  if (choice is MapboxPlace) {
    override.state = await resolveSportCity(
      ref.read(sportOverviewRepositoryProvider),
      choice.name,
    );
  }
}

class _UseDevice {
  const _UseDevice();
}

class _CitySheet extends StatefulWidget {
  const _CitySheet({required this.deviceCity});

  final String? deviceCity;

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
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
    final DabblerColors colors = DabblerColors.of(context);
    final String? device = widget.deviceCity;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DabblerText(
          device == null
              ? l.sport_overview_city_sheet_note
              : l.sport_overview_city_sheet_note_device(device),
          style: DabblerType.smallTight,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        DabblerSearchField(
          controller: _search,
          placeholder: l.manual_location_search_placeholder,
        ),
        if (device != null) ...<Widget>[
          const DabblerGap.v(DabblerSpacing.space3),
          Semantics(
            button: true,
            label: l.sport_overview_city_use_device(device),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(const _UseDevice()),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: DabblerSizing.touchTargetMin,
                ),
                child: Row(
                  children: <Widget>[
                    DabblerIcon(
                      'gps',
                      weight: DabblerIconWeight.bold,
                      size: DabblerSizing.iconSm,
                      color: colors.brandPrimary,
                    ),
                    const DabblerGap.h(DabblerSpacing.space3),
                    Expanded(
                      child: DabblerText(
                        l.sport_overview_city_use_device(device),
                        style: DabblerType.subheadline,
                        weight: DabblerTextWeight.semibold,
                        tone: DabblerTextTone.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
