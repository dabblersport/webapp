import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The body of the delete-account confirmation sheet (`Settings.dc.html:403`):
/// the warning, the destructive confirm and the cancel.
///
/// Extracted from `AccountManagementScreen` so the layout can be verified at
/// the real string lengths in Arabic as well as English (KAN-161 AC2) against
/// the widget the app renders — the screen itself cannot be pumped, it reaches
/// for `Supabase.instance` and an authenticated session.
///
/// The `Type "DELETE"` label is deliberately still a hardcoded English literal:
/// `content-manager` ruled the confirmation token stays a fixed Latin `DELETE`.
class DeleteAccountSheetBody extends StatelessWidget {
  const DeleteAccountSheetBody({
    super.key,
    required this.confirmController,
    required this.deleting,
    required this.onConfirm,
    required this.onCancel,
  });

  final TextEditingController confirmController;
  final bool deleting;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerText(
          l10n.acct_delete_body,
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
        ),
        // The approved retention disclosure (KAN-160) stays: the frame's body
        // does not mention the payment and booking records that are kept.
        const DabblerGap.v(DabblerSpacing.space3),
        DabblerText(
          l10n.account_delete_dialog_warning,
          style: DabblerType.caption1,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space5),
        DabblerTextField(
          controller: confirmController,
          label: 'Type "DELETE" to confirm',
          prefixIcon: const DabblerIcon(
            'warning-2',
            size: DabblerSizing.iconSm,
          ),
          enabled: !deleting,
        ),
        const DabblerGap.v(DabblerSpacing.space5),
        DabblerButton(
          label: l10n.acct_delete_confirm,
          tone: DabblerButtonTone.destructive,
          size: DabblerButtonSize.block,
          loading: deleting,
          onPressed: deleting ? null : onConfirm,
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        DabblerButton(
          label: l10n.acct_cancel,
          tone: DabblerButtonTone.outlined,
          size: DabblerButtonSize.block,
          disabled: deleting,
          onPressed: onCancel,
        ),
      ],
    );
  }
}
