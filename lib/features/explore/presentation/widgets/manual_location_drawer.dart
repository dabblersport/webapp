import 'package:dabbler/core/constants/uae_locations.dart';
import 'package:dabbler/core/services/location_service.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The manual location picker: use the current location, or search and pick
/// from the UAE list. Hosted in a design-system sheet, which owns the surface,
/// the handle and the scrolling; this widget is the sheet's content.
class ManualLocationDrawer extends StatefulWidget {
  const ManualLocationDrawer({super.key});

  @override
  State<ManualLocationDrawer> createState() => _ManualLocationDrawerState();
}

class _ManualLocationDrawerState extends State<ManualLocationDrawer> {
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
    setState(() => _isLoading = true);

    try {
      await _locationService.setManualLocation(
        location.displayName,
        latitude: location.lat,
        longitude: location.lng,
      );

      if (mounted) {
        Navigator.pop(context);
        toast.show(
          DabblerToastSpec(
            message: 'Location set to ${location.displayName}',
            tone: DabblerToastTone.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        toast.show(
          DabblerToastSpec(
            message: 'Failed to update location: $e',
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
    setState(() => _isLoading = true);

    try {
      await _locationService.fetchLocation();

      if (mounted) {
        Navigator.pop(context);
        toast.show(
          const DabblerToastSpec(
            message: 'Location updated',
            tone: DabblerToastTone.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        toast.show(
          DabblerToastSpec(
            message: 'Failed to get location: $e',
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
        DabblerText(
          'Select Location',
          style: DabblerType.headline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DabblerSpacing.space6),
        DabblerButton(
          label: 'Use Current Location',
          icon: 'gps',
          tone: DabblerButtonTone.outlined,
          fullWidth: true,
          loading: _isLoading,
          disabled: _isLoading,
          onPressed: _useCurrentLocation,
        ),
        const SizedBox(height: DabblerSpacing.space6),
        const DabblerDivider(label: 'or choose from list'),
        const SizedBox(height: DabblerSpacing.space6),
        DabblerSearchField(
          controller: _searchController,
          placeholder: 'Search locations...',
        ),
        const SizedBox(height: DabblerSpacing.space4),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(DabblerSpacing.space10),
            child: Center(child: DabblerSpinner()),
          )
        else if (_filteredLocations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(DabblerSpacing.space8),
            child: DabblerEmptyState(
              icon: 'location-slash',
              title: 'No locations found',
              text: 'Try a different search term',
            ),
          )
        else
          for (final LocationData location in _filteredLocations) ...<Widget>[
            _LocationTile(
              location: location,
              onTap: () => _selectLocation(location),
            ),
            const SizedBox(height: DabblerSpacing.space2),
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
