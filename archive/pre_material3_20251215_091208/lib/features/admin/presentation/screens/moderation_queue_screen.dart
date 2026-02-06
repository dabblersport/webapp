import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/core/widgets/loading_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final response = await Supabase.instance.client.rpc('is_admin');
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAdminAsync = ref.watch(isAdminProvider);
    final queueAsync = ref.watch(moderationQueueProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Moderation Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(moderationQueueProvider);
            },
          ),
        ],
      ),
      body: isAdminAsync.when(
        data: (isAdmin) {
          if (!isAdmin) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Access Denied',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You must be an administrator to access this page.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return queueAsync.when(
            data: (reports) {
              if (reports.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'All Clear',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No pending reports in the moderation queue.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(moderationQueueProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _buildReportCard(
                      context,
                      theme,
                      colorScheme,
                      report,
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: LoadingWidget()),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load moderation queue',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        ref.invalidate(moderationQueueProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: LoadingWidget()),
        error: (error, stack) =>
            Center(child: Text('Failed to check admin status: $error')),
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    ModerationReportSummary report,
  ) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final statusColor = _getStatusColor(colorScheme, report.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showReportDetails(context, report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      report.status.toPostgresString().toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateFormat.format(report.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${report.targetType.toPostgresString().toUpperCase()}: ${report.targetId}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reason: ${report.reason.toPostgresString()}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (report.details != null && report.details!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Details: ${report.details}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _resolveReport(
                      context,
                      report.reportId,
                      ReportStatus.dismissed,
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('Dismiss'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _showActionDialog(context, report),
                    icon: const Icon(Icons.gavel),
                    label: const Text('Take Action'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ColorScheme colorScheme, ReportStatus status) {
    switch (status) {
      case ReportStatus.open:
        return colorScheme.primary;
      case ReportStatus.triage:
        return colorScheme.secondary;
      case ReportStatus.escalated:
        return colorScheme.error;
      case ReportStatus.resolved:
        return colorScheme.tertiary;
      case ReportStatus.dismissed:
        return colorScheme.onSurfaceVariant;
      case ReportStatus.duplicate:
        return colorScheme.onSurfaceVariant;
    }
  }

  void _showReportDetails(
    BuildContext context,
    ModerationReportSummary report,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                _buildDetailRow(
                  'Target Type',
                  report.targetType.toPostgresString(),
                ),
                _buildDetailRow('Target ID', report.targetId),
                _buildDetailRow('Reason', report.reason.toPostgresString()),
                _buildDetailRow('Status', report.status.toPostgresString()),
                _buildDetailRow('Report ID', report.reportId),
                _buildDetailRow(
                  'Reported At',
                  DateFormat('MMM dd, yyyy HH:mm').format(report.createdAt),
                ),
                if (report.details != null && report.details!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.details!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report resolved successfully')),
        );
        ref.invalidate(moderationQueueProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to resolve report: $e')));
      }
    }
  }

  void _showActionDialog(BuildContext context, ModerationReportSummary report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take Moderation Action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target: ${report.targetType.toPostgresString()}'),
            Text('ID: ${report.targetId}'),
            const SizedBox(height: 16),
            const Text('Select an action:'),
            const SizedBox(height: 8),
            ...ModAction.values.map(
              (action) => ListTile(
                title: Text(_getActionLabel(action)),
                onTap: () {
                  Navigator.pop(context);
                  _takeAction(context, report, action);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Action "${_getActionLabel(action)}" applied successfully',
            ),
          ),
        );
        ref.invalidate(moderationQueueProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to take action: $e')));
      }
    }
  }
}
