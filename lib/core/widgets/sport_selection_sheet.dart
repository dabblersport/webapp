import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/data/models/social/sport.dart';

/// Reusable bottom-sheet sport picker. Open it with [showComposerSheet] (the
/// sheet supplies the title).
///
/// Pass a [sportsProvider] that returns [AsyncValue<List<Sport>>] so each
/// call site controls which filtered list it gets (e.g. all active sports vs
/// challenge-only sports).
///
/// [selectedSport] highlights the currently selected item.
/// [showClear] + [onClear] opt into a "Clear" action.
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
    final sportsAsync = ref.watch(widget.sportsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showClear && widget.onClear != null)
          ComposerClearRow(
            onClear: () {
              widget.onClear!();
              Navigator.pop(context);
            },
          ),
        sportsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (sports) {
            final categories =
                sports
                    .where((s) => s.category != null && s.category!.isNotEmpty)
                    .map((s) => s.category!)
                    .toSet()
                    .toList()
                  ..sort();
            if (categories.length <= 1) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsetsDirectional.only(
                start: DabblerSpacing.space6,
                end: DabblerSpacing.space6,
                bottom: DabblerSpacing.space3,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DabblerChip(
                      label: 'All',
                      selected: _activeCategoryFilter == null,
                      onTap: () => setState(() => _activeCategoryFilter = null),
                    ),
                    for (final cat in categories) ...[
                      const SizedBox(width: DabblerSpacing.space2),
                      DabblerChip(
                        label: _prettify(cat),
                        selected: _activeCategoryFilter == cat,
                        onTap: () =>
                            setState(() => _activeCategoryFilter = cat),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        sportsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space10),
            child: ComposerCenteredState.loading(),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space8),
            child: ComposerCenteredState.message('Failed to load sports'),
          ),
          data: (sports) {
            var items = sports.toList();
            if (_activeCategoryFilter != null) {
              items = items
                  .where((s) => s.category == _activeCategoryFilter)
                  .toList();
            }
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space8),
                child: ComposerCenteredState.message('No sports available'),
              );
            }
            final colors = DabblerColors.of(context);
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (_, i) {
                final sport = items[i];
                final isSelected = sport.id == widget.selectedSport?.id;
                return DabblerInputRow(
                  title: sport.localizedName(context),
                  subtitle: sport.category != null
                      ? _prettify(sport.category!)
                      : null,
                  leading: DabblerSportIcon.fromKey(
                    (sport.sportKey ?? '').replaceAll('_', '-'),
                    size: DabblerSizing.iconMd,
                    weight: isSelected
                        ? DabblerIconWeight.bold
                        : DabblerIconWeight.linear,
                    color: isSelected
                        ? colors.brandPrimary
                        : colors.textSecondary,
                  ),
                  trailing: isSelected
                      ? DabblerIcon(
                          'tick-circle',
                          weight: DabblerIconWeight.bold,
                          size: DabblerSizing.iconRow,
                          color: colors.brandPrimary,
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
      ],
    );
  }
}

String _prettify(String raw) => raw
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
