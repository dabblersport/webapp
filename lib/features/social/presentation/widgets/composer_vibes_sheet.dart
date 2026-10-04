import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

/// Opens "What's the vibe?" (`Home Feed.dc.html:650-690`): a searchable wrap
/// of vibe chips, a Clear action when something is chosen and a `Confirm`
/// footer that hands the pending vibe to [onConfirm].
Future<void> showComposerVibesSheet(
  BuildContext context,
  WidgetRef ref, {
  required String? selectedVibeId,
  required ValueChanged<Vibe> onConfirm,
  required VoidCallback onClear,
}) {
  final vibes = ref.read(vibesProvider).valueOrNull ?? const <Vibe>[];
  final pending = ValueNotifier<Vibe?>(
    vibes.where((v) => v.id == selectedVibeId).firstOrNull,
  );
  return showComposerSheet<void>(
    context,
    title: "What's the vibe?",
    subtitle: vibes.isEmpty ? null : '${vibes.length} vibes',
    onClear: selectedVibeId == null ? null : onClear,
    tall: true,
    confirm: ComposerSheetConfirm(
      label: 'Confirm',
      onTap: () {
        final vibe = pending.value;
        if (vibe != null) onConfirm(vibe);
        Navigator.of(context).maybePop();
      },
    ),
    builder: (_) => ComposerVibesSheet(pending: pending),
  );
}

/// The search field and vibe chips of [showComposerVibesSheet].
class ComposerVibesSheet extends ConsumerStatefulWidget {
  const ComposerVibesSheet({super.key, required this.pending});

  final ValueNotifier<Vibe?> pending;

  @override
  ConsumerState<ComposerVibesSheet> createState() => _ComposerVibesSheetState();
}

class _ComposerVibesSheetState extends ConsumerState<ComposerVibesSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _label(Vibe v) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    if (ar && v.labelAr.isNotEmpty) return v.labelAr;
    return v.labelEn.isNotEmpty ? v.labelEn : v.key;
  }

  @override
  Widget build(BuildContext context) {
    final vibesAsync = ref.watch(vibesProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComposerSearchField(
          controller: _search,
          placeholder: 'Search vibes',
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        vibesAsync.when(
          loading: () => const ComposerCenteredState.loading(),
          error: (_, __) =>
              const ComposerCenteredState.message('Failed to load vibes'),
          data: (vibes) {
            final shown = vibes
                .where(
                  (v) =>
                      _query.isEmpty ||
                      _label(v).toLowerCase().contains(_query) ||
                      v.key.toLowerCase().contains(_query),
                )
                .toList();
            if (shown.isEmpty) {
              return const ComposerCenteredState.message(
                'No vibes match that search',
              );
            }
            return ValueListenableBuilder<Vibe?>(
              valueListenable: widget.pending,
              builder: (_, current, __) => Wrap(
                spacing: DabblerSpacing.space3,
                runSpacing: DabblerSpacing.space3,
                children: [
                  for (final v in shown)
                    DabblerChip(
                      label: _label(v),
                      vibe: DabblerVibe.fromKey(v.key),
                      selected: current?.id == v.id,
                      onTap: () => widget.pending.value = v,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
