import 'package:dabbler/core/constants/uae_locations.dart';
import 'package:dabbler/core/services/location_service.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The manual location picker: use the current location, or search and pick
/// from the UAE list. Hosted in a design-system sheet, which owns the surface,
/// the handle and the scrolling; this widget is the sheet's content.
class ManualLocationDrawer extends ConsumerStatefulWidget {
  const ManualLocationDrawer({super.key});

  @override
  ConsumerState<ManualLocationDrawer> createState() =>
      _ManualLocationDrawerState();
}

class _ManualLocationDrawerState extends ConsumerState<ManualLocationDrawer> {
  final _searchController = TextEditingController();
  final _locationService = LocationService();
  bool _isLoading = false;
  List<LocationData> _filteredLocations = UAELocations.cities;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredLocations = UAELocations.search(_searchController.text);
    });
  }

  Future<void> _selectLocation(LocationData location) async {
    final toast = DabblerToastProvider.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);

    try {
      await _locationService.setManualLocation(
        location.displayName,
        latitude: location.lat,
        longitude: location.lng,
      );
      // KAN-526: the app's active location too (Games, Meetups, Venues, Home
      // read it), persisted so the choice survives a restart.
      await ref
          .read(activeLocationProvider.notifier)
          .useManualPoint(location.lat, location.lng, location.displayName);

      if (mounted) {
        Navigator.pop(context);
        toast.show(
          DabblerToastSpec(
            message: l10n.manual_location_set_toast(location.displayName),
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DabblerButton(
          label: AppLocalizations.of(context).location_use_current,
          icon: 'gps',
          tone: DabblerButtonTone.outlined,
          fullWidth: true,
          loading: _isLoading,
          disabled: _isLoading,
          onPressed: _useCurrentLocation,
        ),
        const DabblerGap.v(DabblerSpacing.space6),
        DabblerDivider(
          label: AppLocalizations.of(context).manual_location_divider,
        ),
        const DabblerGap.v(DabblerSpacing.space6),
        DabblerSearchField(
          controller: _searchController,
          placeholder: AppLocalizations.of(
            context,
          ).manual_location_search_placeholder,
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(DabblerSpacing.space10),
            child: Center(child: DabblerSpinner()),
          )
        else if (_filteredLocations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(DabblerSpacing.space8),
            child: DabblerEmptyState(
              icon: 'location-slash',
              title: AppLocalizations.of(context).manual_location_empty_title,
              text: AppLocalizations.of(context).manual_location_empty_text,
            ),
          )
        else
          for (final LocationData location in _filteredLocations) ...<Widget>[
            _LocationTile(
              location: location,
              onTap: () => _selectLocation(location),
            ),
            const DabblerGap.v(DabblerSpacing.space2),
          ],
      ],
    );
  }
}

/// Location tile widget for the list
class _LocationTile extends StatelessWidget {
  final LocationData location;
  final VoidCallback onTap;

  const _LocationTile({required this.location, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DabblerInputRow(
      flat: true,
      onTap: onTap,
      leading: const DabblerIcon('location', size: DabblerSizing.iconRow),
      title: location.displayName,
      subtitle: location.city,
      trailing: const DabblerChevron(),
      semanticLabel: location.displayName,
    );
  }
}
