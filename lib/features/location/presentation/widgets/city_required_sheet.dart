import 'package:dabbler/core/constants/uae_locations.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// KAN-587: the City-only step behind "Maybe later" in location setup. It lists
/// canonical cities only (never an Area result), needs no GPS and no area, and
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

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _cities {
    final String q = _search.text.trim().toLowerCase();
    final List<String> all = <String>{
      for (final LocationData l in UAELocations.cities) l.city,
    }.toList();
    return q.isEmpty
        ? all
        : all.where((String c) => c.toLowerCase().contains(q)).toList();
  }

  Future<void> _pick(String city) async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref.read(activeLocationProvider.notifier).useManualCity(city);
    if (mounted) Navigator.pop(context, city);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final List<String> cities = _cities;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DabblerSearchField(
          controller: _search,
          placeholder: l.manual_location_search_placeholder,
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        if (cities.isEmpty)
          Padding(
            padding: const EdgeInsets.all(DabblerSpacing.space8),
            child: DabblerEmptyState(
              icon: 'location-slash',
              title: l.manual_location_empty_title,
              text: l.manual_location_empty_text,
            ),
          )
        else
          for (final String city in cities) ...<Widget>[
            DabblerInputRow(
              flat: true,
              onTap: () => _pick(city),
              leading: const DabblerIcon(
                'location',
                size: DabblerSizing.iconRow,
              ),
              title: city,
              trailing: const DabblerChevron(),
              semanticLabel: city,
            ),
            const DabblerGap.v(DabblerSpacing.space2),
          ],
      ],
    );
  }
}
