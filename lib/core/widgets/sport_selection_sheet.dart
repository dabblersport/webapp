import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Opens the sport picker as a composer sheet (`Home Feed.dc.html:731-760`):
/// the sport rows, a Clear action when [showClear], and a `Confirm` footer
/// that applies the pending choice through [onConfirm].
///
/// Pass a [sportsProvider] that returns [AsyncValue<List<Sport>>] so each
/// call site controls which filtered list it gets (e.g. all active sports vs
/// challenge-only sports).
///
/// [emojiFor] (KAN-478, Create Post only) returns a sport's display emoji;
/// a non-null result is handed to the DS slot `DabblerInputRow.emoji` and
/// replaces the sport icon, as the design row does (`Home Feed.dc.html:742`).
/// Null (the default) keeps every other caller, Create Game included,
/// rendering exactly as before.
Future<void> showComposerSportSheet(
  BuildContext context, {
  required String title,
  required ProviderListenable<AsyncValue<List<Sport>>> sportsProvider,
  required void Function(Sport) onConfirm,
  Sport? selected,
  bool showClear = false,
  VoidCallback? onClear,
  String? Function(Sport)? emojiFor,
}) {
  final pending = ValueNotifier<Sport?>(selected);
  return showComposerSheet<void>(
    context,
    title: title,
    onClear: showClear ? onClear : null,
    confirm: ComposerSheetConfirm(
      label: AppLocalizations.of(context).composer_confirm,
      onTap: () {
        final sport = pending.value;
        if (sport != null) onConfirm(sport);
        Navigator.of(context).maybePop();
      },
    ),
    builder: (_) => SportSelectionSheet(
      sportsProvider: sportsProvider,
      pending: pending,
      emojiFor: emojiFor,
    ),
  );
}

/// The sport rows of [showComposerSportSheet]; a tap marks the pending
/// choice in [pending].
class SportSelectionSheet extends ConsumerWidget {
  const SportSelectionSheet({
    super.key,
    required this.sportsProvider,
    required this.pending,
    this.emojiFor,
  });

  final ProviderListenable<AsyncValue<List<Sport>>> sportsProvider;
  final ValueNotifier<Sport?> pending;

  /// See [showComposerSportSheet]; null draws no emoji anywhere.
  final String? Function(Sport)? emojiFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sportsAsync = ref.watch(sportsProvider);
    return sportsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space10),
        child: ComposerCenteredState.loading(),
      ),
      error: (_, __) => Padding(
        padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space8),
        child: ComposerCenteredState.message(
          AppLocalizations.of(context).composer_sports_failed,
        ),
      ),
      data: (sports) {
        if (sports.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space8),
            child: ComposerCenteredState.message(
              AppLocalizations.of(context).composer_sports_none,
            ),
          );
        }
        final colors = DabblerColors.of(context);
        return ValueListenableBuilder<Sport?>(
          valueListenable: pending,
          builder: (context, current, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final sport in sports) ...[
                DabblerInputRow(
                  title: sport.localizedName(context),
                  emoji: emojiFor?.call(sport),
                  leading: emojiFor?.call(sport) != null
                      ? null
                      : DabblerSportIcon.fromKey(
                          (sport.sportKey ?? '').replaceAll('_', '-'),
                          size: DabblerSizing.iconMd,
                          weight: sport.id == current?.id
                              ? DabblerIconWeight.bold
                              : DabblerIconWeight.linear,
                          color: sport.id == current?.id
                              ? colors.brandPrimary
                              : colors.textSecondary,
                        ),
                  trailing: sport.id == current?.id
                      ? DabblerIcon(
                          'tick-circle',
                          weight: DabblerIconWeight.bold,
                          size: DabblerSizing.iconRow,
                          color: colors.brandPrimary,
                        )
                      : null,
                  onTap: () => pending.value = sport,
                ),
                const DabblerDivider(),
              ],
            ],
          ),
        );
      },
    );
  }
}
