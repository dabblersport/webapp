import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sport tag selector that loads sports dynamically from the DB.
class SportTagSelector extends StatefulWidget {
  final List<String> selectedSports;
  final Function(List<String>) onSportsChanged;

  const SportTagSelector({
    super.key,
    required this.selectedSports,
    required this.onSportsChanged,
  });

  @override
  State<SportTagSelector> createState() => _SportTagSelectorState();
}

class _SportTagSelectorState extends State<SportTagSelector> {
  List<Map<String, dynamic>> _sports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSports();
  }

  Future<void> _loadSports() async {
    try {
      final data = await Supabase.instance.client
          .from('sports')
          .select('id, slug, name')
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _sports = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Fallback to common sports if DB fails
          _sports = _fallbackSports;
        });
      }
    }
  }

  static final List<Map<String, dynamic>> _fallbackSports = [
    {'name': 'Football'},
    {'name': 'Basketball'},
    {'name': 'Tennis'},
    {'name': 'Swimming'},
    {'name': 'Running'},
    {'name': 'Cycling'},
    {'name': 'Golf'},
    {'name': 'Baseball'},
    {'name': 'Soccer'},
    {'name': 'Volleyball'},
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_soccer, color: colorScheme.primary, size: 20),
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
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sports.map((sport) {
                  final name = sport['name']?.toString() ?? '';
                  final isSelected = widget.selectedSports.contains(name);

                  return FilterChip(
                    label: Text(name),
                    selected: isSelected,
                    onSelected: (selected) {
                      final updated = List<String>.from(widget.selectedSports);
                      if (selected) {
                        updated.add(name);
                      } else {
                        updated.remove(name);
                      }
                      widget.onSportsChanged(updated);
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
