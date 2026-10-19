import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/admin/presentation/providers/admin_message_reports_providers.dart';
import 'package:dabbler/features/admin/presentation/screens/moderation_queue_screen.dart'
    show isAdminProvider;
import 'package:dabbler/features/admin/presentation/widgets/admin_reported_message_panel.dart';
import 'package:dabbler/features/messaging/domain/models/report_row.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The admin Reports screen (KAN-552): message reports as ID-ONLY rows
/// (shortened report id, reason, time, status; no names, no text). "Read
/// this message" makes ONE audited read of that report's message and shows
/// it in a panel for this admin only.
///
/// Draws nothing unless both flags are on AND the user is an admin (the
/// existing [isAdminProvider]); the route also redirects non-admins Home.
class AdminMessageReportsScreen extends ConsumerStatefulWidget {
  const AdminMessageReportsScreen({super.key});

  static const listKey = ValueKey<String>('admin-message-reports-list');
  static const loadingKey = ValueKey<String>('admin-message-reports-loading');
  static const emptyKey = ValueKey<String>('admin-message-reports-empty');
  static const errorKey = ValueKey<String>('admin-message-reports-error');

  static ValueKey<String> rowKey(String reportId) =>
      ValueKey<String>('admin-message-reports-row-$reportId');

  static ValueKey<String> readKey(String reportId) =>
      ValueKey<String>('admin-message-reports-read-$reportId');

  @override
  ConsumerState<AdminMessageReportsScreen> createState() =>
      _AdminMessageReportsScreenState();
}

class _AdminMessageReportsScreenState
    extends ConsumerState<AdminMessageReportsScreen> {
  /// True from a tap until its panel closes: a second tap is ignored.
  bool _reading = false;

  Future<void> _read(String reportId) async {
    if (_reading) return;
    _reading = true;
    try {
      await showAdminReportedMessagePanel(
        context: context,
        repository: ref.read(moderationReportsRepositoryProvider),
        reportId: reportId,
      );
    } finally {
      _reading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = adminMessageReportsEnabled(
      ref.watch(adminMessageReportsFlagsProvider),
    );
    final isAdmin = ref.watch(isAdminProvider).valueOrNull == true;
    if (!enabled || !isAdmin) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final async = ref.watch(adminMessageReportsProvider);
    final result = async.valueOrNull;
    final Widget body;
    if (result == null || async.isLoading) {
      body = Semantics(
        key: AdminMessageReportsScreen.loadingKey,
        container: true,
        label: l10n.admin_message_reports_loading,
        child: ExcludeSemantics(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: DabblerInsets.screen,
            children: [
              for (var i = 0; i < 5; i++)
                const Padding(
                  padding: EdgeInsetsDirectional.only(
                    bottom: DabblerSpacing.space6,
                  ),
                  child: DabblerSkeleton.text(lines: 3),
                ),
            ],
          ),
        ),
      );
    } else if (result is Ok<List<ReportRow>, Object>) {
      final rows = result.requireValue;
      body = rows.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: DabblerEmptyState(
                  key: AdminMessageReportsScreen.emptyKey,
                  icon: 'flag',
                  size: DabblerEmptyStateSize.page,
                  title: l10n.admin_message_reports_empty_title,
                  text: l10n.admin_message_reports_empty_body,
                ),
              ),
            )
          : _list(context, l10n, rows);
    } else {
      body = Center(
        child: SingleChildScrollView(
          child: DabblerEmptyState.error(
            key: AdminMessageReportsScreen.errorKey,
            title: l10n.admin_message_reports_error_title,
            text: l10n.admin_message_reports_error_body,
            retryLabel: l10n.admin_message_reports_error_retry,
            onRetry: () => ref.invalidate(adminMessageReportsProvider),
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
    List<ReportRow> rows,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    return ListView.builder(
      key: AdminMessageReportsScreen.listKey,
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space7),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final r = rows[i];
        return Column(
          key: AdminMessageReportsScreen.rowKey(r.reportId),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DabblerListRow(
              overline: l10n.admin_message_reports_row_id(
                adminShortReportId(r.reportId),
              ),
              title: adminReportReasonLabel(l10n, r.reason),
              subtitle: adminReportTime(r.createdAt, locale),
              trailing: DabblerBadge(
                label: adminReportStatusLabel(l10n, r.status),
                tone: DabblerBadgeTone.warning,
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: DabblerListRow.paddingInline,
                end: DabblerListRow.paddingInline,
                bottom: DabblerSpacing.space4,
              ),
              child: DabblerButton(
                key: AdminMessageReportsScreen.readKey(r.reportId),
                label: l10n.admin_message_reports_read_action,
                icon: 'eye',
                size: DabblerButtonSize.small,
                tone: DabblerButtonTone.outlined,
                onPressed: () => _read(r.reportId),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The first 8 characters of a report id.
String adminShortReportId(String id) =>
    id.length <= 8 ? id : id.substring(0, 8);

String adminReportTime(DateTime at, String locale) =>
    DateFormat.yMMMd(locale).add_jm().format(at.toLocal());

String adminReportReasonLabel(AppLocalizations l10n, String reason) =>
    switch (reason) {
      'spam' => l10n.admin_message_reports_reason_spam,
      'abuse' => l10n.admin_message_reports_reason_abuse,
      'hate' => l10n.admin_message_reports_reason_hate,
      'harassment' => l10n.admin_message_reports_reason_harassment,
      'nudity' => l10n.admin_message_reports_reason_nudity,
      'illegal' => l10n.admin_message_reports_reason_illegal,
      'danger' => l10n.admin_message_reports_reason_danger,
      'scam' => l10n.admin_message_reports_reason_scam,
      'impersonation' => l10n.admin_message_reports_reason_impersonation,
      'other' => l10n.admin_message_reports_reason_other,
      _ => l10n.admin_message_reports_reason_unknown,
    };

String adminReportStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'open' => l10n.admin_message_reports_status_open,
      'triage' => l10n.admin_message_reports_status_triage,
      'escalated' => l10n.admin_message_reports_status_escalated,
      'resolved' => l10n.admin_message_reports_status_resolved,
      'dismissed' => l10n.admin_message_reports_status_dismissed,
      'duplicate' => l10n.admin_message_reports_status_duplicate,
      _ => l10n.admin_message_reports_status_unknown,
    };
