import 'package:flutter/material.dart';

/// Enum for trending categories
enum TrendingCategory {
  all,
  sports,
  basketball,
  football,
  soccer,
  baseball,
  tennis,
  golf,
  gaming,
  fitness,
}

/// Enum for trending time ranges
enum TrendingTimeRange { today, thisWeek, thisMonth, allTime }

/// Filter bar widget for trending posts
class TrendingFilterBar extends StatelessWidget {
  final TrendingCategory selectedCategory;
  final TrendingTimeRange selectedTimeRange;
  final ValueChanged<TrendingCategory>? onCategoryChanged;
  final ValueChanged<TrendingTimeRange>? onTimeRangeChanged;

  const TrendingFilterBar({
    super.key,
    required this.selectedCategory,
    required this.selectedTimeRange,
    this.onCategoryChanged,
    this.onTimeRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Category filter
          Row(
            children: [
              Text('Category:', style: theme.textTheme.labelMedium),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: TrendingCategory.values.map((category) {
                      final isSelected = category == selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_getCategoryName(category)),
                          selected: isSelected,
                          onSelected: (_) => onCategoryChanged?.call(category),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Time range filter
          Row(
            children: [
              Text('Time Range:', style: theme.textTheme.labelMedium),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: TrendingTimeRange.values.map((timeRange) {
                      final isSelected = timeRange == selectedTimeRange;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_getTimeRangeName(timeRange)),
                          selected: isSelected,
                          onSelected: (_) =>
                              onTimeRangeChanged?.call(timeRange),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCategoryName(TrendingCategory category) {
    switch (category) {
      case TrendingCategory.all:
        return 'All';
      case TrendingCategory.sports:
        return 'Sports';
      case TrendingCategory.basketball:
        return 'Basketball';
      case TrendingCategory.football:
        return 'Football';
      case TrendingCategory.soccer:
        return 'Soccer';
      case TrendingCategory.baseball:
        return 'Baseball';
      case TrendingCategory.tennis:
        return 'Tennis';
      case TrendingCategory.golf:
        return 'Golf';
      case TrendingCategory.gaming:
        return 'Gaming';
      case TrendingCategory.fitness:
        return 'Fitness';
    }
  }

  String _getTimeRangeName(TrendingTimeRange timeRange) {
    switch (timeRange) {
      case TrendingTimeRange.today:
        return 'Today';
      case TrendingTimeRange.thisWeek:
        return 'This Week';
      case TrendingTimeRange.thisMonth:
        return 'This Month';
      case TrendingTimeRange.allTime:
        return 'All Time';
    }
  }
}
