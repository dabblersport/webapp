import 'package:flutter/material.dart';

/// A widget for displaying filter chips in the social feed
class FeedFilterChips extends StatelessWidget {
  final String currentFilter;
  final Function(String) onFilterChanged;

  const FeedFilterChips({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = currentFilter == filter.value;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter.label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onFilterChanged(filter.value);
                }
              },
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: isSelected ? 2 : 1,
              ),
            ),
          );
        },
      ),
    );
  }

  static const List<FilterOption> _filters = [
    FilterOption('all', 'All'),
    FilterOption('friends', 'Friends'),
    FilterOption('public', 'Public'),
    FilterOption('game', 'Games'),
    FilterOption('photos', 'Photos'),
    FilterOption('videos', 'Videos'),
  ];
}

/// Represents a filter option
class FilterOption {
  final String value;
  final String label;

  const FilterOption(this.value, this.label);
}
