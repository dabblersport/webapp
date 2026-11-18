import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The delete-account row in its own "Danger zone" group. Public so the render
/// test can pump it.
class AccountDangerZone extends StatelessWidget {
  const AccountDangerZone({super.key, required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerRowGroup(
      header: l10n.acct_group_danger,
      children: [
        DabblerInputRow(
          flat: true,
          showDivider: false,
          title: l10n.acct_delete_title,
          subtitle: l10n.acct_delete_sub,
          tone: DabblerInputRowTone.destructive,
          leading: const DabblerIcon('trash', size: DabblerSizing.iconRow),
          onTap: onDelete,
        ),
      ],
    );
  }
}
