import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Opens "What's the vibe?" (`Home Feed.dc.html:650-690`): a searchable wrap
/// of vibe chips, a Clear action when something is chosen and a `Confirm`
/// footer that hands the pending vibe to [onConfirm]. As tall as its chips,
/// up to the frame's `max-height: 82%`. [kindLabel] is the localized name of
/// the post kind the count subtitle names. With [postType], only the vibes the
/// design offers for that kind are listed (`Home Feed.dc.html` `vibesFor()`,
/// the `contexts` of each vibe, carried by [DabblerVibe.contexts]) and the
/// count is theirs.
Future<void> showComposerVibesSheet(
  BuildContext context,
  WidgetRef ref, {
  required String? selectedVibeId,
  required String kindLabel,
  PostType? postType,
  required ValueChanged<Vibe> onConfirm,
  required VoidCallback onClear,
}) {
  final vibes = composerVibesFor(
    ref.read(vibesProvider).valueOrNull ?? const <Vibe>[],
    postType,
  );
  final pending = ValueNotifier<Vibe?>(
    vibes.where((v) => v.id == selectedVibeId).firstOrNull,
  );
  final confirm = ComposerSheetConfirm(
    label: AppLocalizations.of(context).composer_confirm,
    onTap: () {
      final vibe = pending.value;
      if (vibe != null) onConfirm(vibe);
      Navigator.of(context).maybePop();
    },
  );
  final l = AppLocalizations.of(context);
  final title = l.home_vibe_title;
  // The design lowercases the kind in English only ('12 vibes for dab').
  final kind = Localizations.localeOf(context).languageCode == 'en'
      ? kindLabel.toLowerCase()
      : kindLabel;
  // Content-sized, capped at the frame's 82% (`sheetP82`).
  return showDabblerSheet<void>(
    context: context,
    title: title,
    titleWidget: composerSheetTitle(
      title,
      subtitle: vibes.isEmpty
          ? null
          : l.composer_vibe_count(vibes.length, kind),
    ),
    detent: DabblerSheetDetent.content,
    contentMaxFraction: DabblerSheet.contentMaxFractionTall,
    pageBackground: true,
    hairlineOutside: ComposerFrameScope.active(context),
    showCloseButton: false,
    headerActionBuilder: (ctx) =>
        composerSheetHeaderActions(context, ctx, onClear: onClear),
    footerBuilder: (_) => composerSheetFooter(confirm),
    builder: composerFrameBuilder(
      context,
      (_) => ComposerVibesSheet(pending: pending, postType: postType),
    ),
  );
}

/// The design context a [PostType] offers vibes in; `null` for a kind the
/// design has no vibe list for.
DabblerVibeContext? composerVibeContext(PostType? type) => switch (type) {
  PostType.moment => DabblerVibeContext.moment,
  PostType.dab => DabblerVibeContext.dab,
  PostType.kickIn => DabblerVibeContext.kickin,
  _ => null,
};

/// [vibes] limited to those the design offers for [type] (unfiltered when
/// [type] has no design context). A vibe whose key the design does not know
/// is not offered for any kind.
List<Vibe> composerVibesFor(List<Vibe> vibes, PostType? type) {
  final ctx = composerVibeContext(type);
  if (ctx == null) return vibes;
  return [
    for (final v in vibes)
      if (DabblerVibe.fromKey(v.key)?.contexts.contains(ctx) ?? false) v,
  ];
}

/// The search field and vibe chips of [showComposerVibesSheet].
class ComposerVibesSheet extends ConsumerStatefulWidget {
  const ComposerVibesSheet({super.key, required this.pending, this.postType});

  final ValueNotifier<Vibe?> pending;
  final PostType? postType;

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
          placeholder: AppLocalizations.of(context).composer_vibe_search,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        vibesAsync.when(
          loading: () => const ComposerCenteredState.loading(),
          error: (_, __) => ComposerCenteredState.message(
            AppLocalizations.of(context).composer_vibe_failed,
          ),
          data: (vibes) {
            final shown = composerVibesFor(vibes, widget.postType)
                .where(
                  (v) =>
                      _query.isEmpty ||
                      _label(v).toLowerCase().contains(_query) ||
                      v.key.toLowerCase().contains(_query),
                )
                .toList();
            if (shown.isEmpty) {
              return ComposerCenteredState.message(
                AppLocalizations.of(context).composer_vibe_none,
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
