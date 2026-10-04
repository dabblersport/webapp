import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The bar every Settings sub-page wears (`Settings.dc.html:48-58`): the
/// bordered back button, the page name, and the information action — the same
/// destination the Settings root's information action opens.
DabblerNavigationTopBar settingsTopBar(
  BuildContext context, {
  required String title,
  required VoidCallback onBack,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return DabblerNavigationTopBar.titled(
    border: true,
    title: title,
    onBack: onBack,
    actions: <DabblerNavigationAction>[
      DabblerNavigationAction(
        icon: 'information',
        label: l10n.settings_header_help_tooltip,
        onPressed: () => context.push('/help/center'),
      ),
    ],
  );
}

/// The padding of a Settings sub-page's scrolling column
/// (`Settings.dc.html:130`: `18px 15px 36px`).
const EdgeInsetsGeometry kSettingsBodyPadding = EdgeInsetsDirectional.fromSTEB(
  DabblerSpacing.space5,
  DabblerSpacing.space6,
  DabblerSpacing.space5,
  DabblerSpacing.space10,
);

/// The gap between a Settings sub-page's groups (`gap: 18px`).
const Widget kSettingsGroupGap = DabblerGap.v(DabblerSpacing.space6);

/// The leading glyph of a Settings row: 21px in the soft text role
/// (`Settings.dc.html:140` — `color: var(--ink-soft)`).
Widget settingsRowIcon(BuildContext context, String name) => DabblerIcon(
  name,
  size: DabblerSizing.iconRow,
  color: DabblerColors.of(context).textSecondary,
);
