import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/social/sport.dart';

/// Reusable bottom-sheet sport picker.
///
/// Pass a [sportsProvider] that returns [AsyncValue<List<Sport>>] so each
/// call site controls which filtered list it gets (e.g. all active sports vs
/// challenge-only sports).
///
/// [selectedSport] highlights the currently selected item.
/// [showClear] + [onClear] opt into a "Clear" header button.
class SportSelectionSheet extends ConsumerStatefulWidget {
  const SportSelectionSheet({
    super.key,
    required this.sportsProvider,
    required this.onSelect,
    this.selectedSport,
    this.showClear = false,
    this.onClear,
  });

  final ProviderListenable<AsyncValue<List<Sport>>> sportsProvider;
  final void Function(Sport) onSelect;
  final Sport? selectedSport;
  final bool showClear;
  final VoidCallback? onClear;

  @override
  ConsumerState<SportSelectionSheet> createState() =>
      _SportSelectionSheetState();
}

class _SportSelectionSheetState extends ConsumerState<SportSelectionSheet> {
  String? _activeCategoryFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sportsAsync = ref.watch(widget.sportsProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (the M3 drag handle comes from showAdaptiveSheet).
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              children: [
                Text(
                  'Sports',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                if (widget.showClear && widget.onClear != null)
                  TextButton(
                    onPressed: () {
                      widget.onClear!();
                      Navigator.pop(context);
                    },
                    child: Text('Clear', style: TextStyle(color: cs.primary)),
                  ),
              ],
            ),
          ),

          // Category filter chips
          sportsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (sports) {
              final categories = sports
                  .where((s) => s.category != null && s.category!.isNotEmpty)
                  .map((s) => s.category!)
                  .toSet()
                  .toList()
                ..sort();
              if (categories.length <= 1) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _activeCategoryFilter == null,
                        onTap: () =>
                            setState(() => _activeCategoryFilter = null),
                      ),
                      const SizedBox(width: 8),
                      for (final cat in categories) ...[
                        _FilterChip(
                          label: _prettify(cat),
                          isSelected: _activeCategoryFilter == cat,
                          onTap: () =>
                              setState(() => _activeCategoryFilter = cat),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          // Sports list
          Flexible(
            child: sportsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Failed to load sports',
                    style: TextStyle(color: cs.error),
                  ),
                ),
              ),
              data: (sports) {
                var items = sports.toList();
                if (_activeCategoryFilter != null) {
                  items = items
                      .where((s) => s.category == _activeCategoryFilter)
                      .toList();
                }
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No sports available',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final sport = items[i];
                    final isSelected = sport.id == widget.selectedSport?.id;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: isSelected
                          ? cs.primaryContainer
                          : Colors.transparent,
                      leading: Text(
                        sport.emoji ?? '🏅',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        sport.localizedName(context),
                        style: tt.bodyMedium?.copyWith(
                          color: isSelected
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      subtitle: sport.category != null
                          ? Text(
                              _prettify(sport.category!),
                              style: tt.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            )
                          : null,
                      onTap: () {
                        widget.onSelect(sport);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LOCAL HELPERS
// =============================================================================

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

String _prettify(String raw) => raw
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
