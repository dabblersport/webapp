import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_parts.dart';

/// Provider for moderation queue
final moderationQueueProvider = FutureProvider<List<ModerationReportSummary>>((
  ref,
) async {
  final service = ref.read(moderationServiceProvider);
  return await service.fetchOpenModQueue();
});

/// Provider for admin status check
final isAdminProvider = FutureProvider<bool>((ref) async {
  try {
    final response = await Supabase.instance.client.rpc(
      SupabaseConfig.isAdminFn,
    );
    return response == true;
  } catch (e) {
    return false;
  }
});

class ModerationQueueScreen extends ConsumerStatefulWidget {
  const ModerationQueueScreen({super.key});

  @override
  ConsumerState<ModerationQueueScreen> createState() =>
      _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends ConsumerState<ModerationQueueScreen> {
  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(isAdminProvider);
    final queueAsync = ref.watch(moderationQueueProvider);

    // One layout at every width: the wide-screen rail wrapper is
    // not a DS component; the app shell owns wide navigation.
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Moderation Queue',
        onBack: Navigator.of(context).canPop()
            ? () => Navigator.of(context).maybePop()
            : null,
        actions: [
          DabblerNavigationAction(
            icon: 'refresh',
            label: 'Refresh',
            onPressed: () {
              ref.invalidate(moderationQueueProvider);
            },
          ),
        ],
      ),
      body: isAdminAsync.when(
        data: (isAdmin) {
          if (!isAdmin) return const AdminAccessDenied();

          return queueAsync.when(
            data: (reports) {
              if (reports.isEmpty) {
                return const Center(
                  child: DabblerEmptyState(
                    icon: 'tick-circle',
                    size: DabblerEmptyStateSize.page,
                    title: 'All Clear',
                    text: 'No pending reports in the moderation queue.',
                  ),
                );
              }

              return DabblerRefresh(
                onRefresh: () async {
                  ref.invalidate(moderationQueueProvider);
                },
                child: ListView.separated(
                  padding: DabblerInsets.screen,
                  itemCount: reports.length,
                  separatorBuilder: (_, _) =>
                      const DabblerGap.v(DabblerSpacing.space4),
                  itemBuilder: (context, index) =>
                      _buildReportCard(context, reports[index]),
                ),
              );
            },
            loading: () => const AdminLoading(),
            error: (error, stack) => AdminErrorState(
              title: 'Failed to load moderation queue',
              text: error.toString(),
              onRetry: () {
                ref.invalidate(moderationQueueProvider);
              },
            ),
          );
        },
        loading: () => const AdminLoading(),
        error: (error, stack) => Center(
          child: DabblerText(
            'Failed to check admin status: $error',
            style: DabblerType.body,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    ModerationReportSummary report,
  ) {
    final colors = DabblerColors.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return DabblerCard(
      onTap: () => _showReportDetails(context, report),
      header: Row(
        children: [
          DabblerBadge(
            label: report.status.toPostgresString().toUpperCase(),
            status: _statusColor(colors, report.status),
            tone: DabblerBadgeTone.warning,
          ),
          const Spacer(),
          DabblerText(
            dateFormat.format(report.createdAt),
            style: DabblerType.footnote,
            tone: DabblerTextTone.secondary,
          ),
        ],
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DabblerButton(
            label: 'Dismiss',
            icon: 'close-circle',
            tone: DabblerButtonTone.outlined,
            size: DabblerButtonSize.small,
            onPressed: () => _resolveReport(
              context,
              report.reportId,
              ReportStatus.dismissed,
            ),
          ),
          const DabblerGap.h(DabblerSpacing.space3),
          DabblerButton(
            label: 'Take Action',
            icon: 'judge',
            size: DabblerButtonSize.small,
            onPressed: () => _showActionDialog(context, report),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DabblerText(
            '${report.targetType.toPostgresString().toUpperCase()}: ${report.targetId}',
            style: DabblerType.headline,
          ),
          const DabblerGap.v(DabblerSpacing.space1),
          DabblerText(
            'Reason: ${report.reason.toPostgresString()}',
            style: DabblerType.subheadline,
            tone: DabblerTextTone.secondary,
          ),
          if (report.details != null && report.details!.isNotEmpty) ...[
            const DabblerGap.v(DabblerSpacing.space1),
            DabblerText(
              'Details: ${report.details}',
              style: DabblerType.footnote,
              tone: DabblerTextTone.secondary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// Report status to a DS status role. The old Material scheme used
  /// primary/secondary/tertiary; dismissed/duplicate fall back to the neutral
  /// (warning-tone) badge.
  DabblerStatusColor? _statusColor(DabblerColors colors, ReportStatus status) {
    switch (status) {
      case ReportStatus.open:
        return colors.info;
      case ReportStatus.triage:
        return colors.warning;
      case ReportStatus.escalated:
        return colors.error;
      case ReportStatus.resolved:
        return colors.success;
      case ReportStatus.dismissed:
      case ReportStatus.duplicate:
        return null;
    }
  }

  void _showReportDetails(
    BuildContext context,
    ModerationReportSummary report,
  ) {
    showDabblerSheet<void>(
      context: context,
      title: 'Report Details',
      detents: const <double>[0.7, 0.95],
      builder: (context) {
        return ListView(
          padding: DabblerInsets.screen,
          children: [
            _detailRow('Target Type', report.targetType.toPostgresString()),
            _detailRow('Target ID', report.targetId),
            _detailRow('Reason', report.reason.toPostgresString()),
            _detailRow('Status', report.status.toPostgresString()),
            _detailRow('Report ID', report.reportId),
            _detailRow(
              'Reported At',
              DateFormat('MMM dd, yyyy HH:mm').format(report.createdAt),
            ),
            if (report.details != null && report.details!.isNotEmpty)
              DabblerInputRow(
                title: 'Details',
                subtitle: report.details,
                flat: true,
                showDivider: false,
              ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) => DabblerInputRow(
    title: label,
    value: value,
    flat: true,
    showDivider: false,
  );

  void _toast(String message, DabblerToastTone tone) {
    DabblerToastProvider.of(context)
        .show(DabblerToastSpec(message: message, tone: tone));
  }

  Future<void> _resolveReport(
    BuildContext context,
    String reportId,
    ReportStatus status,
  ) async {
    try {
      final service = ref.read(moderationServiceProvider);
      await service.adminResolveReport(
        reportId: reportId,
        status: status,
        resolution: 'Resolved via moderation queue',
      );

      if (mounted) {
        _toast('Report resolved successfully', DabblerToastTone.success);
        ref.invalidate(moderationQueueProvider);
      }
    } catch (e) {
      if (mounted) {
        _toast('Failed to resolve report: $e', DabblerToastTone.error);
      }
    }
  }

  void _showActionDialog(BuildContext context, ModerationReportSummary report) {
    showDabblerDialog<void>(
      context: context,
      builder: (dialogContext) => DabblerDialog(
        title: 'Take Moderation Action',
        description:
            'Target: ${report.targetType.toPostgresString()}\nID: ${report.targetId}',
        onClose: () => Navigator.pop(dialogContext),
        secondaryAction: DabblerDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(dialogContext),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DabblerText(
              'Select an action:',
              style: DabblerType.subheadline,
              tone: DabblerTextTone.secondary,
            ),
            const DabblerGap.v(DabblerSpacing.space2),
            for (final action in ModAction.values)
              DabblerInputRow(
                title: _getActionLabel(action),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _takeAction(context, report, action);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _getActionLabel(ModAction action) {
    switch (action) {
      case ModAction.warn:
        return 'Warn User';
      case ModAction.freeze:
        return 'Freeze User';
      case ModAction.unfreeze:
        return 'Unfreeze User';
      case ModAction.shadowban:
        return 'Shadowban User';
      case ModAction.unshadowban:
        return 'Unshadowban User';
      case ModAction.takedown:
        return 'Takedown Content';
      case ModAction.restore:
        return 'Restore Content';
      case ModAction.restrict:
        return 'Restrict User';
      case ModAction.ban:
        return 'Ban User';
      case ModAction.unban:
        return 'Unban User';
    }
  }

  Future<void> _takeAction(
    BuildContext context,
    ModerationReportSummary report,
    ModAction action,
  ) async {
    try {
      final service = ref.read(moderationServiceProvider);
      await service.adminTakeAction(
        targetType: report.targetType,
        targetId: report.targetId,
        action: action,
        reason: 'Action taken from moderation queue',
      );

      if (mounted) {
        _toast(
          'Action "${_getActionLabel(action)}" applied successfully',
          DabblerToastTone.success,
        );
        ref.invalidate(moderationQueueProvider);
      }
    } catch (e) {
      if (mounted) {
        _toast('Failed to take action: $e', DabblerToastTone.error);
      }
    }
  }
}
