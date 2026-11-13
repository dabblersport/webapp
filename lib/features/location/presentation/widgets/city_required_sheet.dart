import 'dart:async';

import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/presentation/widgets/map_place_results.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// KAN-587: the City-only step behind "Maybe later" in location setup. It lists
/// map-service cities worldwide (never an Area result), needs no GPS and no area, and
/// commits the choice as the device's manual city. Resolves to the chosen city,
/// or null when the sheet is dismissed without one.
Future<String?> showCityRequiredSheet(BuildContext context) {
  return showAppSheet<String>(
    context: context,
    title: AppLocalizations.of(context).manual_location_cities_divider,
    detent: DabblerSheetDetent.content,
    builder: (_) => const CityRequiredSheet(),
  );
}

class CityRequiredSheet extends ConsumerStatefulWidget {
  const CityRequiredSheet({super.key});

  @override
  ConsumerState<CityRequiredSheet> createState() => _CityRequiredSheetState();
}

class _CityRequiredSheetState extends ConsumerState<CityRequiredSheet> {
  final TextEditingController _search = TextEditingController();
  bool _saving = false;
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

  Future<void> _pick(MapboxPlace place) async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref
        .read(activeLocationProvider.notifier)
        .useManualCity(
          place.name,
          cityId: place.id,
          country: place.country,
          countryCode: place.countryCode,
        );
    if (mounted) Navigator.pop(context, place.name);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
          MapPlaceResults.cities(query: _query, onPick: _pick),
      ],
    );
  }
}
