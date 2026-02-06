import 'package:flutter/material.dart';

class SportTagSelector extends StatelessWidget {
  final List<String> selectedSports;
  final Function(List<String>) onSportsChanged;

  const SportTagSelector({
    super.key,
    required this.selectedSports,
    required this.onSportsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final availableSports = [
      'Football',
      'Basketball',
      'Tennis',
      'Swimming',
      'Running',
      'Cycling',
      'Golf',
      'Baseball',
      'Soccer',
      'Volleyball',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sports_soccer,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sports/Activities',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableSports.map((sport) {
                final isSelected = selectedSports.contains(sport);

                return FilterChip(
                  label: Text(sport),
                  selected: isSelected,
                  onSelected: (selected) {
                    final updatedSports = List<String>.from(selectedSports);
                    if (selected) {
                      updatedSports.add(sport);
                    } else {
                      updatedSports.remove(sport);
                    }
                    onSportsChanged(updatedSports);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
