import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/design_system/widgets/app_search_input.dart';
import 'package:dabbler/core/services/location_service.dart';
import 'package:dabbler/core/constants/uae_locations.dart';
import 'package:dabbler/themes/material3_extensions.dart';

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
    setState(() => _isLoading = true);

    try {
      await _locationService.setManualLocation(
        location.displayName,
        latitude: location.lat,
        longitude: location.lng,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location set to ${location.displayName}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update location: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
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
    setState(() => _isLoading = true);

    try {
      await _locationService.fetchLocation();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.categorySports.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Select Location',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Use current location button
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _useCurrentLocation,
                      icon: _isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.categorySports,
                              ),
                            )
                          : const Icon(Iconsax.gps_copy, size: 20),
                      label: const Text('Use Current Location'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.categorySports,
                        side: BorderSide(color: colorScheme.categorySports),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Divider with "or choose" text
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: colorScheme.categorySports.withOpacity(0.3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or choose from list',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.categorySports.withOpacity(
                                0.8,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: colorScheme.categorySports.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search input
                    AppSearchInput(
                      controller: _searchController,
                      hintText: 'Search locations...',
                      lightStyle: false,
                    ),
                  ],
                ),
              ),

              // Location list
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: colorScheme.categorySports,
                        ),
                      )
                    : _filteredLocations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.location_slash_copy,
                              size: 64,
                              color: colorScheme.categorySports.withOpacity(
                                0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No locations found',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different search term',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _filteredLocations.length,
                        itemBuilder: (context, index) {
                          final location = _filteredLocations[index];
                          return _LocationTile(
                            location: location,
                            onTap: () => _selectLocation(location),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Location icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.categorySports.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Iconsax.location_copy,
                  size: 20,
                  color: colorScheme.categorySports,
                ),
              ),
              const SizedBox(width: 12),

              // Location info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.displayName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location.city,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Iconsax.arrow_right_3_copy,
                size: 20,
                color: colorScheme.categorySports,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
