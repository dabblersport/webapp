import 'package:dabbler/core/config/sport_filters_config.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

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
    final DabblerColors colors = DabblerColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space4),
      child: Text(
        title,
        style: listingText(
          context,
          DabblerType.headline,
          color: colors.textPrimary,
        ),
      ),
    );
  }

  Widget buildChipGroup(
    BuildContext context,
    List<String> options,
    String filterKey,
  ) {
    final selectedValue = selectedFilters[filterKey];

    return Wrap(
      spacing: DabblerSpacing.space3,
      runSpacing: DabblerSpacing.space3,
      children: options.map((option) {
        final isSelected =
            selectedValue == option ||
            (selectedValue == null && option == 'All');

        return DabblerChip(
          label: option,
          selected: isSelected,
          onTap: () {
            // A chip is only ever selected here, never toggled off.
            if (!isSelected) {
              onFilterChanged(filterKey, option == 'All' ? null : option);
            }
          },
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
        const SizedBox(height: DabblerSpacing.space7),
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
        const SizedBox(height: DabblerSpacing.space7),
        buildSectionTitle(context, 'Ball Type'),
        buildChipGroup(
          context,
          SportFiltersConfig.cricketBallTypes,
          'ballType',
        ),
        const SizedBox(height: DabblerSpacing.space7),
        buildSectionTitle(context, 'Over Format'),
        buildChipGroup(
          context,
          SportFiltersConfig.cricketOverFormats,
          'overFormat',
        ),
        const SizedBox(height: DabblerSpacing.space7),
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
        const SizedBox(height: DabblerSpacing.space7),
        buildSectionTitle(context, 'Court Type'),
        buildChipGroup(
          context,
          SportFiltersConfig.padelCourtTypes,
          'courtType',
        ),
        const SizedBox(height: DabblerSpacing.space7),
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
