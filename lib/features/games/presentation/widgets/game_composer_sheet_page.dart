import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The Create game routes' page (KAN-472, Orchestrator ruling D-035): the
/// route presents the composer exactly as Create meet-up's
/// `showMeetupComposerSheet` does — the design-system sheet
/// ([DabblerSheetRoute]) on the page colour, content-sized up to 94%
/// (`sheetP94`, `Home Feed.dc.html:925-927`), over the DS scrim, a scrim tap
/// closing it, with the frame's sticky header: the title in 22/28 display and a
/// small neutral Cancel.
///
/// Only the presentation changes: the go_router route keeps its path, name,
/// redirect and gate; [child] is what the route built before.
class GameComposerSheetPage extends Page<void> {
  const GameComposerSheetPage({
    super.key,
    required this.child,
    this.editing = false,
  });

  /// The routed composer (with its gate).
  final Widget child;

  /// Titles the sheet "Edit Game" instead of "Create game".
  final bool editing;

  @override
  Route<void> createRoute(BuildContext context) => DabblerSheetRoute<void>(
    settings: this,
    detent: DabblerSheetDetent.content,
    contentMaxFraction: DabblerSheet.contentMaxFractionFull,
    pageBackground: true,
    showCloseButton: false,
    titleWidget: GameComposerSheetTitle(editing: editing),
    headerActionBuilder: (sheetContext) => GameComposerCancel(
      onPressed: () => Navigator.of(sheetContext).maybePop(),
    ),
    builder: (_) => child,
  );
}

/// The frame's title: `Create game` (or `Edit Game`), display 22/28 ink.
class GameComposerSheetTitle extends StatelessWidget {
  const GameComposerSheetTitle({super.key, this.editing = false});

  final bool editing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DabblerText(
      editing ? l.game_edit : l.game_create,
      style: DabblerType.title2,
    );
  }
}

/// The frame's small neutral Cancel.
class GameComposerCancel extends StatelessWidget {
  const GameComposerCancel({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DabblerButton(
    label: AppLocalizations.of(context).composer_cancel,
    tone: DabblerButtonTone.neutral,
    size: DabblerButtonSize.small,
    onPressed: onPressed,
  );
}
