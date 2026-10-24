import 'dart:async';

import 'package:dabbler/core/services/location_service.dart';
import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/auth_onboarding/domain/location/service_region.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/service_region_labels.dart';
import 'package:dabbler/features/location/data/manual_location_catalog.dart';
import 'package:dabbler/features/location/presentation/widgets/country_flag.dart';
import 'package:dabbler/features/location/presentation/widgets/map_place_results.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The manual location picker (KAN-640): country first, then a city of that
/// country, then an area of that city. Nothing is committed until an area is
/// chosen. Cities and areas come from the app's own tables, and from the map
/// service for a city those tables lack. Hosted in a design-system sheet,
/// which owns the surface, the handle and the scrolling; this widget is the
/// sheet's content.
class ManualLocationDrawer extends ConsumerStatefulWidget {
  const ManualLocationDrawer({super.key});

  @override
  ConsumerState<ManualLocationDrawer> createState() =>
      _ManualLocationDrawerState();
}

/// The city chosen in step two.
class _City {
  const _City({required this.name, required this.label, this.id, this.catalog});

  /// The English name that is stored.
  final String name;

  /// The name shown in the current language.
  final String label;
  final String? id;
  final CatalogCity? catalog;
}

class _ManualLocationDrawerState extends ConsumerState<ManualLocationDrawer> {
  final _searchController = TextEditingController();
  final _locationService = LocationService();
  bool _isLoading = false;
  Timer? _debounce;

  /// The debounced map-service query; empty (under 2 characters) searches
  /// only the app's own list.
  String _mapQuery = '';

  _City? _city;

  /// KAN-640 R5: the drawer's country IS the app's country (the one shared
  /// `selectedCountryProvider`, also behind the Location screen's selector).
  /// Null when it is Global, which shows the country list first.
  String? get _country {
    final String c = normalizeServiceRegion(
      ref.read(selectedCountryProvider).valueOrNull,
    );
    return c == kGlobalRegion ? null : c;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
    _debounce?.cancel();
    final String q = _searchController.text.trim();
    if (q.length < 2) {
      if (_mapQuery.isNotEmpty) setState(() => _mapQuery = '');
      return;
    }
    _debounce = Timer(DabblerMotion.debounceSearch, () {
      if (mounted) setState(() => _mapQuery = q);
    });
  }

  void _resetSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _mapQuery = '';
  }

  void _pickCountry(String country) {
    setState(() {
      _resetSearch();
      _city = null;
    });
    ref.read(selectedCountryProvider.notifier).setCountry(country);
  }

  void _changeCountry() {
    setState(() {
      _resetSearch();
      _city = null;
    });
    ref.read(selectedCountryProvider.notifier).setCountry(kGlobalRegion);
  }

  void _pickCity(_City city) {
    setState(() {
      _resetSearch();
      _city = city;
    });
  }

  void _changeCity() {
    setState(() {
      _resetSearch();
      _city = null;
    });
  }

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  /// The final step: the area completes the manual address.
  Future<void> _pickArea({
    required String name,
    required double lat,
    required double lng,
  }) async {
    final _City? city = _city;
    final String? country = _country;
    if (city == null || country == null) return;
    final toast = DabblerToastProvider.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    try {
      await _locationService.setManualLocation(
        name,
        latitude: lat,
        longitude: lng,
      );
      final notifier = ref.read(activeLocationProvider.notifier);
      await notifier.useManualCity(
        city.name,
        cityId: city.id,
        country: country,
        countryCode: kCountryIsoCodes[country],
      );
      await notifier.useManualPoint(
        lat,
        lng,
        name,
        city: city.name,
        area: name,
      );
      if (mounted) {
        Navigator.pop(context);
        toast.show(
          DabblerToastSpec(
            message: l10n.manual_location_set_toast(name),
            tone: DabblerToastTone.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        toast.show(
          DabblerToastSpec(
            message: l10n.manual_location_set_failed('$e'),
            tone: DabblerToastTone.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    final toast = DabblerToastProvider.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);

    try {
      await _locationService.fetchLocation(requestPermission: true);

      if (mounted) {
        Navigator.pop(context);
        toast.show(
          DabblerToastSpec(
            message: l10n.manual_location_updated_toast,
            tone: DabblerToastTone.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        toast.show(
          DabblerToastSpec(
            message: l10n.manual_location_fetch_failed('$e'),
            tone: DabblerToastTone.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Rebuild when the app's country changes (the Location screen's selector).
    ref.watch(selectedCountryProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(DabblerSpacing.space10),
            child: Center(child: DabblerSpinner()),
          )
        else if (_country == null)
          ..._countryStep(l)
        else if (_city == null)
          ..._cityStep(l, _country!)
        else
          ..._areaStep(l, _country!, _city!),
      ],
    );
  }

  /// Step one: the country. No city is offered until one is chosen.
  List<Widget> _countryStep(AppLocalizations l) {
    final String lang = Localizations.localeOf(context).languageCode;
    return <Widget>[
      DabblerButton(
        label: l.location_use_current,
        icon: 'gps',
        tone: DabblerButtonTone.outlined,
        fullWidth: true,
        loading: _isLoading,
        disabled: _isLoading,
        onPressed: _useCurrentLocation,
      ),
      const DabblerGap.v(DabblerSpacing.space6),
      DabblerDivider(label: l.manual_location_divider),
      const DabblerGap.v(DabblerSpacing.space4),
      DabblerDivider(label: l.location_intro_country_title),
      const DabblerGap.v(DabblerSpacing.space4),
      for (final (String c, String label) in serviceRegionOptions(
        l,
        lang,
      ).where(((String, String) o) => o.$1 != kGlobalRegion)) ...<Widget>[
        DabblerInputRow(
          flat: true,
          onTap: () => _pickCountry(c),
          leading: CountryFlag(region: c, size: DabblerSizing.iconRow),
          title: label,
          trailing: const DabblerChevron(),
          semanticLabel: label,
        ),
        const DabblerGap.v(DabblerSpacing.space2),
      ],
    ];
  }

  /// The chosen country or city, with the way back to change it.
  Widget _chosenChip({
    required Widget leading,
    required String title,
    required String changeLabel,
    required VoidCallback onChange,
  }) {
    return DabblerInputRow(
      flat: true,
      onTap: onChange,
      leading: leading,
      title: title,
      trailing: DabblerText(
        changeLabel,
        style: DabblerType.subheadline,
        weight: DabblerTextWeight.semibold,
        tone: DabblerTextTone.brand,
      ),
      semanticLabel: '$title, $changeLabel',
    );
  }

  /// Step two: a city of the chosen country.
  List<Widget> _cityStep(AppLocalizations l, String country) {
    final String q = _searchController.text.trim().toLowerCase();
    final List<CatalogCity> all =
        ref.watch(catalogCitiesProvider(country)).valueOrNull ??
        const <CatalogCity>[];
    final bool loading = ref.watch(catalogCitiesProvider(country)).isLoading;
    final List<CatalogCity> shown = <CatalogCity>[
      for (final CatalogCity c in all)
        if (q.isEmpty ||
            c.nameEn.toLowerCase().contains(q) ||
            c.nameAr.toLowerCase().contains(q))
          c,
    ];
    final String? iso = kCountryIsoCodes[country];
    return <Widget>[
      _chosenChip(
        leading: CountryFlag(region: country, size: DabblerSizing.iconRow),
        title: serviceRegionLabel(l, country),
        changeLabel: l.location_intro_country_change,
        onChange: _changeCountry,
      ),
      const DabblerGap.v(DabblerSpacing.space4),
      DabblerSearchField(
        controller: _searchController,
        placeholder: l.manual_location_search_city,
      ),
      const DabblerGap.v(DabblerSpacing.space4),
      DabblerDivider(label: l.manual_location_cities_divider),
      const DabblerGap.v(DabblerSpacing.space4),
      if (loading && all.isEmpty)
        const Padding(
          padding: EdgeInsets.all(DabblerSpacing.space8),
          child: Center(child: DabblerSpinner()),
        ),
      for (final CatalogCity c in shown) ...<Widget>[
        DabblerInputRow(
          flat: true,
          onTap: () => _pickCity(
            _City(
              name: c.nameEn,
              label: c.name(_isArabic),
              id: c.code,
              catalog: c,
            ),
          ),
          leading: const DabblerIcon('location', size: DabblerSizing.iconRow),
          title: c.name(_isArabic),
          trailing: const DabblerChevron(),
          semanticLabel: c.name(_isArabic),
        ),
        const DabblerGap.v(DabblerSpacing.space2),
      ],
      if (_mapQuery.isNotEmpty && iso != null)
        MapPlaceResults.countryCities(
          query: (query: _mapQuery, countryCode: iso),
          onPick: (MapboxPlace p) =>
              _pickCity(_City(name: p.name, label: p.name, id: p.id)),
        )
      else if (!loading && shown.isEmpty)
        Padding(
          padding: const EdgeInsets.all(DabblerSpacing.space8),
          child: DabblerEmptyState(
            icon: 'location-slash',
            title: l.manual_location_empty_title,
            text: l.manual_location_empty_text,
          ),
        ),
    ];
  }

  /// Step three: an area of the chosen city. Choosing one completes the
  /// address; there is no way to finish with the city alone.
  List<Widget> _areaStep(AppLocalizations l, String country, _City city) {
    final String q = _searchController.text.trim().toLowerCase();
    final CatalogCity? catalog = city.catalog;
    final AsyncValue<List<CatalogArea>>? async = catalog == null
        ? null
        : ref.watch(catalogAreasProvider(catalog));
    final List<CatalogArea> all = async?.valueOrNull ?? const <CatalogArea>[];
    final bool loading = async?.isLoading ?? false;
    final List<CatalogArea> shown = <CatalogArea>[
      for (final CatalogArea a in all)
        if (q.isEmpty || a.name.toLowerCase().contains(q)) a,
    ];
    return <Widget>[
      _chosenChip(
        leading: const DabblerIcon('location', size: DabblerSizing.iconRow),
        title: city.label,
        changeLabel: l.manual_location_change_city,
        onChange: _changeCity,
      ),
      const DabblerGap.v(DabblerSpacing.space2),
      DabblerText(
        l.manual_location_area_hint,
        style: DabblerType.footnote,
        tone: DabblerTextTone.secondary,
      ),
      const DabblerGap.v(DabblerSpacing.space4),
      DabblerSearchField(
        controller: _searchController,
        placeholder: l.manual_location_search_area(city.label),
      ),
      const DabblerGap.v(DabblerSpacing.space4),
      DabblerDivider(label: l.manual_location_areas_in(city.label)),
      const DabblerGap.v(DabblerSpacing.space4),
      if (loading && all.isEmpty)
        const Padding(
          padding: EdgeInsets.all(DabblerSpacing.space8),
          child: Center(child: DabblerSpinner()),
        ),
      for (final CatalogArea a in shown) ...<Widget>[
        DabblerInputRow(
          flat: true,
          onTap: () => _pickArea(name: a.name, lat: a.lat, lng: a.lng),
          leading: const DabblerIcon('location', size: DabblerSizing.iconRow),
          title: a.name,
          subtitle: city.label,
          trailing: const DabblerChevron(),
          semanticLabel: a.name,
        ),
        const DabblerGap.v(DabblerSpacing.space2),
      ],
      if (_mapQuery.isNotEmpty)
        MapPlaceResults.areas(
          query: (
            query: '$_mapQuery, ${city.name}',
            countryCode: kCountryIsoCodes[country],
            proximity: null,
          ),
          onPick: (MapboxPlace p) =>
              _pickArea(name: p.name, lat: p.lat, lng: p.lng),
        )
      else if (!loading && shown.isEmpty)
        Padding(
          padding: const EdgeInsets.all(DabblerSpacing.space8),
          child: DabblerEmptyState(
            icon: 'location-slash',
            title: l.manual_location_empty_title,
            text: l.manual_location_empty_text,
          ),
        ),
    ];
  }
}
