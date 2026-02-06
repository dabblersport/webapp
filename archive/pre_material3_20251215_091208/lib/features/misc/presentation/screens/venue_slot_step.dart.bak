import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dabbler/data/models/core/game_creation_model.dart';
import 'package:dabbler/core/viewmodels/game_creation_viewmodel.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/widgets/loading_spinner.dart';

class VenueSlotStep extends StatefulWidget {
  final GameCreationViewModel viewModel;

  const VenueSlotStep({super.key, required this.viewModel});

  @override
  State<VenueSlotStep> createState() => _VenueSlotStepState();
}

class _VenueSlotStepState extends State<VenueSlotStep> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _selectedFilters = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and Filters
        _buildSearchAndFilters(context),

        // Venue List
        Expanded(
          child: widget.viewModel.state.isLoading
              ? const LoadingSpinner()
              : _buildVenueList(context),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: context.colors.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Choose venue & time',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a venue and available time slot for your ${widget.viewModel.state.selectedSport} game',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search venues...',
              prefixIcon: Icon(
                LucideIcons.search,
                color: context.colors.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: context.colors.outline.withValues(alpha: 0.1),
                ),
              ),
              filled: true,
              fillColor: context.violetWidgetBg,
            ),
            onChanged: (value) {},
          ),
          const SizedBox(height: 16),

          // Filters
          _buildFilters(context),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final availableFilters = [
      {'name': 'Parking', 'icon': LucideIcons.car},
      {'name': 'Shower', 'icon': LucideIcons.droplets},
      {'name': 'Equipment', 'icon': LucideIcons.dumbbell},
      {'name': 'Lighting', 'icon': LucideIcons.lightbulb},
      {'name': 'Food & Drinks', 'icon': LucideIcons.coffee},
      {'name': 'AC', 'icon': LucideIcons.snowflake},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Amenities',
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
            const Spacer(),
            if (_selectedFilters.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedFilters.clear();
                  });
                  widget.viewModel.updateVenueFilters([]);
                },
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableFilters.map((filter) {
            final name = filter['name'] as String;
            final icon = filter['icon'] as IconData;
            final isSelected = _selectedFilters.contains(name.toLowerCase());

            return GestureDetector(
              onTap: () => _toggleFilter(name.toLowerCase()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.colors.primary
                      : context.violetWidgetBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected
                          ? context.colors.onPrimary
                          : context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: context.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? context.colors.onPrimary
                            : context.colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVenueList(BuildContext context) {
    final venues = widget.viewModel.availableVenues;

    if (venues.isEmpty) {
      return _buildEmptyState(context);
    }

    // Group venues by venue name
    final groupedVenues = <String, List<VenueSlot>>{};
    for (final venue in venues) {
      groupedVenues.putIfAbsent(venue.venueName, () => []).add(venue);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedVenues.length,
      itemBuilder: (context, index) {
        final venueName = groupedVenues.keys.elementAt(index);
        final venueSlots = groupedVenues[venueName]!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildVenueCard(context, venueName, venueSlots),
        );
      },
    );
  }

  Widget _buildVenueCard(
    BuildContext context,
    String venueName,
    List<VenueSlot> slots,
  ) {
    final venue = slots.first; // Get venue info from first slot

    return Container(
      decoration: BoxDecoration(
        color: context.violetWidgetBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Venue Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.mapPin,
                    color: context.colors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venueName,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.mapPin,
                            size: 14,
                            color: context.colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              venue.location,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(LucideIcons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            venue.rating.toStringAsFixed(1),
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Amenities
          if (venue.amenities != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAmenities(context, venue.amenities!),
            ),
            const SizedBox(height: 16),
          ],

          // Time Slots
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Time Slots',
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: slots
                      .map((slot) => _buildTimeSlotChip(context, slot))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenities(BuildContext context, Map<String, dynamic> amenities) {
    final amenityIcons = {
      'parking': LucideIcons.car,
      'shower': LucideIcons.droplets,
      'equipment': LucideIcons.dumbbell,
      'lighting': LucideIcons.lightbulb,
    };

    final availableAmenities = amenities.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();

    if (availableAmenities.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableAmenities.map((amenity) {
        final icon = amenityIcons[amenity] ?? LucideIcons.check;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: context.colors.primary),
              const SizedBox(width: 4),
              Text(
                amenity.capitalize(),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeSlotChip(BuildContext context, VenueSlot slot) {
    final isSelected = widget.viewModel.state.selectedVenueSlot == slot;
    final startTime = TimeOfDay.fromDateTime(slot.timeSlot.startTime);
    final endTime = TimeOfDay.fromDateTime(slot.timeSlot.endTime);

    return GestureDetector(
      onTap: () => widget.viewModel.selectVenueSlot(slot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : context.colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? context.colors.primary
                : context.colors.outline.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${startTime.format(context)} - ${endTime.format(context)}',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? context.colors.onPrimary
                    : context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'AED ${slot.timeSlot.price.toStringAsFixed(0)}',
              style: context.textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? context.colors.onPrimary.withValues(alpha: 0.8)
                    : context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.colors.outline.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              LucideIcons.calendar,
              size: 48,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No venues available',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search criteria',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedFilters.clear();
                _searchController.clear();
              });
              widget.viewModel.updateVenueFilters([]);
            },
            child: Text(
              'Reset Filters',
              style: TextStyle(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        _selectedFilters.add(filter);
      }
    });
    widget.viewModel.updateVenueFilters(_selectedFilters);
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
