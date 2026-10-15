import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/l10n/app_localizations.dart';

/// The panel that shows ONE reported message to the admin who tapped Read
/// (KAN-552). The text is held only by this widget for as long as the sheet is
/// open: it is not selectable, so it cannot be copied from here, and it is
/// never passed to a logger, event tracker, error reporter or storage.
abstract final class ReportedMessagePanelKeys {
  static const sheet = ValueKey<String>('admin-message-reports-panel');
  static const text = ValueKey<String>('admin-message-reports-panel-text');
  static const close = ValueKey<String>('admin-message-reports-panel-close');
}

/// Opens the panel and completes when it is closed. The caller must not keep
/// [text] after this future completes.
Future<void> showReportedMessagePanel(BuildContext context, String text) {
  final l10n = AppLocalizations.of(context);
  return showDabblerSheet<void>(
    context: context,
    detent: DabblerSheetDetent.content,
    title: l10n.admin_message_reports_panel_title,
    builder: (sheet) => SingleChildScrollView(
      child: DabblerSheetBody(
        key: ReportedMessagePanelKeys.sheet,
        actions: DabblerSheetActions(
          children: [
            DabblerButton(
              key: ReportedMessagePanelKeys.close,
              label: l10n.admin_message_reports_panel_close,
              tone: DabblerButtonTone.neutral,
              fullWidth: true,
              onPressed: () => Navigator.of(sheet).pop(),
            ),
          ],
        ),
        children: [
          DabblerText(
            text,
            key: ReportedMessagePanelKeys.text,
            style: DabblerType.body,
          ),
          DabblerText(
            l10n.admin_message_reports_panel_note,
            style: DabblerType.footnote,
          ),
        ],
      ),
    ),
  );
}
