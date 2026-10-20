import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/models/report_row.dart';
import 'package:dabbler/features/messaging/domain/moderation_reports_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Opens the reported-message panel for ONE report (KAN-552). The panel makes
/// exactly one audited read when it opens; the text lives only in the
/// panel's state and is dropped when the panel closes.
Future<void> showAdminReportedMessagePanel({
  required BuildContext context,
  required ModerationReportsRepository repository,
  required String reportId,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppSheet<void>(
    context: context,
    detent: DabblerSheetDetent.content,
    title: l10n.admin_message_reports_panel_title,
    builder: (_) =>
        AdminReportedMessagePanel(repository: repository, reportId: reportId),
  );
}

/// The panel body. Not a provider and not cached anywhere: the fetched text
/// is a field of this State and is cleared in [State.dispose].
class AdminReportedMessagePanel extends StatefulWidget {
  const AdminReportedMessagePanel({
    super.key,
    required this.repository,
    required this.reportId,
  });

  final ModerationReportsRepository repository;
  final String reportId;

  static const bodyKey = ValueKey<String>('admin-reported-message-body');
  static const refusalKey = ValueKey<String>('admin-reported-message-refusal');
  static const loadingKey = ValueKey<String>('admin-reported-message-loading');
  static const closeKey = ValueKey<String>('admin-reported-message-close');

  @override
  State<AdminReportedMessagePanel> createState() =>
      _AdminReportedMessagePanelState();
}

class _AdminReportedMessagePanelState extends State<AdminReportedMessagePanel> {
  ReportedMessage? _message;
  Failure? _failure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await widget.repository.readReportedMessage(widget.reportId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result is Ok<ReportedMessage, Failure>) {
        _message = result.requireValue;
      } else {
        _failure = result.requireError;
      }
    });
  }

  @override
  void dispose() {
    _message = null;
    _failure = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = _message;
    final List<Widget> children;
    if (_loading) {
      children = [
        Semantics(
          key: AdminReportedMessagePanel.loadingKey,
          label: l10n.admin_message_reports_panel_loading,
          child: const DabblerSkeleton.text(lines: 3),
        ),
      ];
    } else if (message != null) {
      children = [
        DabblerText(
          message.body,
          key: AdminReportedMessagePanel.bodyKey,
          style: DabblerType.body,
        ),
        DabblerText(
          l10n.admin_message_reports_panel_note,
          style: DabblerType.caption1,
        ),
      ];
    } else {
      children = [
        DabblerText(
          adminReportRefusalText(l10n, _failure),
          key: AdminReportedMessagePanel.refusalKey,
          style: DabblerType.body,
        ),
      ];
    }
    return SingleChildScrollView(
      child: DabblerSheetBody(
        actions: DabblerSheetActions(
          children: [
            DabblerButton(
              key: AdminReportedMessagePanel.closeKey,
              label: l10n.admin_message_reports_panel_close,
              tone: DabblerButtonTone.outlined,
              fullWidth: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        children: children,
      ),
    );
  }
}

/// A plain, localized refusal line; never includes any message text.
String adminReportRefusalText(AppLocalizations l10n, Failure? failure) {
  if (failure is NotAModeratorFailure) {
    return l10n.admin_message_reports_refusal_not_a_moderator;
  }
  if (failure is MessagingFailure) {
    if (failure.reason == MessagingReason.notFound) {
      return l10n.admin_message_reports_refusal_not_found;
    }
    if (failure.reason == MessagingReason.rateLimited) {
      return l10n.admin_message_reports_refusal_rate_limited;
    }
  }
  return l10n.admin_message_reports_refusal_other;
}
