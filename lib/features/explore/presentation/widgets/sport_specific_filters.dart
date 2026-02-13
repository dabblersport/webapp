import 'package:flutter/material.dart';
import 'package:dabbler/core/config/sport_filters_config.dart';
import 'package:dabbler/core/theme/color_token_extensions.dart';

/// Base widget for sport-specific filters
abstract class SportSpecificFilters extends StatelessWidget {
  final Map<String, dynamic> selectedFilters;
  final Function(String key, dynamic value) onFilterChanged;

  const SportSpecificFilters({
    super.key,
    required this.selectedFilters,
    required this.onFilterChanged,
  });

  Widget buildSectionTitle(BuildContext context, String title) {
    final sportsScheme = context.getCategoryTheme('sports');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: sportsScheme.primary,
        ),
      ),
    );
  }

  Widget buildChipGroup(
    BuildContext context,
    List<String> options,
    String filterKey,
  ) {
    final sportsScheme = context.getCategoryTheme('sports');
    final selectedValue = selectedFilters[filterKey];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected =
            selectedValue == option ||
            (selectedValue == null && option == 'All');

        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              onFilterChanged(filterKey, option == 'All' ? null : option);
            }
          },
          backgroundColor: sportsScheme.surfaceContainerHighest,
          selectedColor: sportsScheme.primaryContainer,
          checkmarkColor: sportsScheme.onPrimaryContainer,
          labelStyle: TextStyle(
            color: isSelected
                ? sportsScheme.onPrimaryContainer
                : sportsScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? Colors.transparent
                  : sportsScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Football-specific filters
class FootballFilters extends SportSpecificFilters {
  const FootballFilters({
    super.key,
    required super.selectedFilters,
    required super.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle(context, 'Game Type'),
        buildChipGroup(
          context,
          SportFiltersConfig.footballGameTypes,
          'gameType',
        ),
        const SizedBox(height: 20),
        buildSectionTitle(context, 'Surface Type'),
        buildChipGroup(
          context,
          SportFiltersConfig.footballSurfaceTypes,
          'surfaceType',
        ),
      ],
    );
  }
}

/// Cricket-specific filters
class CricketFilters extends SportSpecificFilters {
  const CricketFilters({
    super.key,
    required super.selectedFilters,
    required super.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle(context, 'Match Format'),
        buildChipGroup(
          context,
          SportFiltersConfig.cricketGameTypes,
          'gameType',
        ),
        const SizedBox(height: 20),
        buildSectionTitle(context, 'Ball Type'),
        buildChipGroup(
          context,
          SportFiltersConfig.cricketBallTypes,
          'ballType',
        ),
        const SizedBox(height: 20),
        buildSectionTitle(context, 'Over Format'),
        buildChipGroup(
          context,
          SportFiltersConfig.cricketOverFormats,
          'overFormat',
        ),
        const SizedBox(height: 20),
        buildSectionTitle(context, 'Pitch Type'),
        buildChipGroup(
          context,
          SportFiltersConfig.cricketPitchTypes,
          'pitchType',
        ),
      ],
    );
  }
}

/// Padel-specific filters
class PadelFilters extends SportSpecificFilters {
  const PadelFilters({
    super.key,
    required super.selectedFilters,
    required super.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle(context, 'Game Type'),
        buildChipGroup(context, SportFiltersConfig.padelGameTypes, 'gameType'),
        const SizedBox(height: 20),
        buildSectionTitle(context, 'Court Type'),
        buildChipGroup(
          context,
          SportFiltersConfig.padelCourtTypes,
          'courtType',
        ),
        const SizedBox(height: 20),
        buildSectionTitle(context, 'Surface Type'),
        buildChipGroup(
          context,
          SportFiltersConfig.padelSurfaceTypes,
          'surfaceType',
        ),
      ],
    );
  }
}

/// Factory to get the appropriate sport-specific filter widget
class SportSpecificFiltersFactory {
  static Widget? create({
    required String sport,
    required Map<String, dynamic> selectedFilters,
    required Function(String key, dynamic value) onFilterChanged,
  }) {
    switch (sport.toLowerCase()) {
      case 'football':
        return FootballFilters(
          selectedFilters: selectedFilters,
          onFilterChanged: onFilterChanged,
        );
      case 'cricket':
        return CricketFilters(
          selectedFilters: selectedFilters,
          onFilterChanged: onFilterChanged,
        );
      case 'padel':
        return PadelFilters(
          selectedFilters: selectedFilters,
          onFilterChanged: onFilterChanged,
        );
      default:
        return null;
    }
  }
}
