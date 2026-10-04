import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/l10n/app_localizations.dart';

/// The inner-page header of the Settings design (`Settings.dc.html`,
/// `isInner`): a back button, the page title, an information action to the
/// help centre, and a hairline underneath.
DabblerNavigationTopBar settingsInnerTopBar(
  BuildContext context, {
  required String title,
  List<DabblerNavigationAction> extraActions = const [],
}) {
  final l10n = AppLocalizations.of(context);
  return DabblerNavigationTopBar.titled(
    border: true,
    title: title,
    onBack: () => context.pop(),
    actions: [
      ...extraActions,
      DabblerNavigationAction(
        icon: 'information',
        label: l10n.settings_header_help_tooltip,
        onPressed: () => context.push('/help/center'),
      ),
    ],
  );
}
