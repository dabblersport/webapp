import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/admin/presentation/providers/message_reports_providers.dart';
import 'package:dabbler/features/admin/presentation/widgets/reported_message_panel.dart';
import 'package:dabbler/features/messaging/domain/message_reports_repository.dart';
import 'package:dabbler/features/messaging/domain/models/message_report.dart';
import 'package:dabbler/features/messaging/domain/models/report_category.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_safety_sheets.dart'
    show reportCategoryLabel;
import 'package:dabbler/l10n/app_localizations.dart';

import 'moderation_queue_screen.dart' show isAdminProvider;

/// The admin-only Reports screen (KAN-552): message reports as id-only rows,
/// and for one chosen report an audited "Read this message" action.
///
/// It exists only for an admin with `FeatureFlags.messaging` and
/// `enableMessagingReporting` on; for anyone else it draws nothing. Rows show
/// the shortened report id, reason, time and status: no names, no content.
/// The text of a message appears only in the panel opened by tapping Read, for
/// the admin who tapped; it is fetched once per tap and dropped when the panel
/// closes. There is no auto-read, no batch read and no list with text.
class MessageReportsScreen extends ConsumerWidget {
  const MessageReportsScreen({super.key});

  static const loadingKey = ValueKey<String>('admin-message-reports-loading');
  static const emptyKey = ValueKey<String>('admin-message-reports-empty');
  static const errorKey = ValueKey<String>('admin-message-reports-error');
  static const listKey = ValueKey<String>('admin-message-reports-list');
  static const refusalKey = ValueKey<String>('admin-message-reports-refusal');

  static ValueKey<String> rowKey(String reportId) =>
      ValueKey<String>('admin-message-reports-row-$reportId');
  static ValueKey<String> readKey(String reportId) =>
      ValueKey<String>('admin-message-reports-read-$reportId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!messageReportsEnabled(ref.watch(messageReportsFlagsProvider))) {
      return const SizedBox.shrink();
    }
    final isAdmin = ref.watch(isAdminProvider);
    // Not an admin (or not yet known to be): nothing is drawn and nothing is
    // requested.
    if (isAdmin.valueOrNull != true) return const SizedBox.shrink();
    return const _ReportsPage();
  }
}

class _ReportsPage extends ConsumerStatefulWidget {
  const _ReportsPage();

  @override
  ConsumerState<_ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<_ReportsPage> {
  /// The report whose read is in flight (one at a time).
  String? _busyId;

  /// The refusal of the last read, shown as a plain message; never text.
  MessageReportsRefusal? _refusal;

  Future<void> _read(MessageReport report) async {
    if (_busyId != null) return;
    setState(() {
      _busyId = report.reportId;
      _refusal = null;
    });
    final result = await ref
        .read(messageReportsRepositoryProvider)
        .readReportedMessage(report.reportId);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (result.isSuccess) {
      // The text lives only in this closure and the panel; both are gone when
      // the sheet closes.
      await showReportedMessagePanel(context, result.requireValue.text);
      return;
    }
    final error = result.requireError;
    setState(
      () => _refusal = error is MessageReportsFailure
          ? error.refusal
          : MessageReportsRefusal.failed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(messageReportsProvider);
    final result = async.valueOrNull;
    final Widget body;
    if (result == null || async.isLoading) {
      body = Center(
        child: Semantics(
          label: l10n.admin_message_reports_loading,
          child: const DabblerSpinner(key: MessageReportsScreen.loadingKey),
        ),
      );
    } else if (result is Ok<List<MessageReport>, dynamic>) {
      final reports = result.requireValue;
      body = reports.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: DabblerEmptyState(
                  key: MessageReportsScreen.emptyKey,
                  icon: 'flag',
                  title: l10n.admin_message_reports_empty,
                  size: DabblerEmptyStateSize.page,
                ),
              ),
            )
          : _list(context, l10n, reports);
    } else {
      body = Center(
        child: SingleChildScrollView(
          child: DabblerEmptyState.error(
            key: MessageReportsScreen.errorKey,
            title: l10n.admin_message_reports_error_title,
            text: l10n.admin_message_reports_error_body,
            retryLabel: l10n.admin_message_reports_retry,
            onRetry: () => ref.invalidate(messageReportsProvider),
          ),
        ),
      );
    }
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: l10n.admin_message_reports_title,
        backLabel: l10n.auth_back,
        onBack: () => context.canPop() ? context.pop() : null,
      ),
      body: body,
    );
  }

  Widget _list(
    BuildContext context,
    AppLocalizations l10n,
    List<MessageReport> reports,
  ) {
    final locale = Localizations.localeOf(context).toString();
    final refusal = _refusal;
    return ListView(
      key: MessageReportsScreen.listKey,
      padding: DabblerInsets.screen,
      children: [
        if (refusal != null) ...[
          DabblerInlineMessage(
            _refusalText(l10n, refusal),
            key: MessageReportsScreen.refusalKey,
          ),
          const DabblerGap.v(DabblerSpacing.space4),
        ],
        for (final report in reports) ...[
          _ReportRow(
            report: report,
            l10n: l10n,
            when: DateFormat.MMMEd(
              locale,
            ).add_jm().format(report.createdAt.toLocal()),
            busy: _busyId == report.reportId,
            canRead: _busyId == null,
            onRead: () => _read(report),
          ),
          const DabblerGap.v(DabblerSpacing.space4),
        ],
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.report,
    required this.l10n,
    required this.when,
    required this.busy,
    required this.canRead,
    required this.onRead,
  });

  final MessageReport report;
  final AppLocalizations l10n;
  final String when;
  final bool busy;
  final bool canRead;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) => DabblerCard(
    key: MessageReportsScreen.rowKey(report.reportId),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DabblerListRow(
          flat: true,
          overline: messageReportReasonLabel(l10n, report.reason),
          title: l10n.admin_message_reports_report_id(report.shortId),
          subtitle: when,
          trailing: DabblerBadge(
            label: messageReportStatusLabel(l10n, report.status),
          ),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        DabblerButton(
          key: MessageReportsScreen.readKey(report.reportId),
          label: busy
              ? l10n.admin_message_reports_reading
              : l10n.admin_message_reports_read_action,
          icon: 'eye',
          tone: DabblerButtonTone.neutral,
          fullWidth: true,
          loading: busy,
          onPressed: canRead ? onRead : null,
        ),
      ],
    ),
  );
}

/// The localized label of a report reason; unknown wire names read as other.
String messageReportReasonLabel(AppLocalizations l10n, String wire) {
  for (final c in ReportCategory.values) {
    if (c.wireName == wire) return reportCategoryLabel(l10n, c);
  }
  return l10n.admin_message_reports_reason_unknown;
}

/// The localized label of a report status.
String messageReportStatusLabel(AppLocalizations l10n, String wire) =>
    switch (wire) {
      'open' => l10n.admin_message_reports_status_open,
      'triage' => l10n.admin_message_reports_status_triage,
      'escalated' => l10n.admin_message_reports_status_escalated,
      'resolved' => l10n.admin_message_reports_status_resolved,
      'dismissed' => l10n.admin_message_reports_status_dismissed,
      'duplicate' => l10n.admin_message_reports_status_duplicate,
      _ => l10n.admin_message_reports_status_unknown,
    };

String _refusalText(AppLocalizations l10n, MessageReportsRefusal r) =>
    switch (r) {
      MessageReportsRefusal.notAModerator =>
        l10n.admin_message_reports_refusal_not_moderator,
      MessageReportsRefusal.notFound =>
        l10n.admin_message_reports_refusal_not_found,
      MessageReportsRefusal.rateLimited =>
        l10n.admin_message_reports_refusal_rate_limited,
      MessageReportsRefusal.failed => l10n.admin_message_reports_refusal_failed,
    };
