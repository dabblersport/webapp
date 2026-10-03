import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dabbler/services/moderation_service.dart';

import 'admin_parts.dart';
import 'moderation_queue_screen.dart';

/// Provider for safety overview
final safetyOverviewProvider = FutureProvider<SafetyOverview>((ref) async {
  final service = ref.read(moderationServiceProvider);
  return await service.fetchSafetyOverview();
});

class SafetyOverviewScreen extends ConsumerWidget {
  const SafetyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);
    final overviewAsync = ref.watch(safetyOverviewProvider);

    // One layout at every width: the Material AdaptiveScaffold rail wrapper is
    // not a DS component; the app shell owns wide navigation.
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Safety Overview',
        onBack: Navigator.of(context).canPop()
            ? () => Navigator.of(context).maybePop()
            : null,
        actions: [
          DabblerNavigationAction(
            icon: 'refresh',
            label: 'Refresh',
            onPressed: () {
              ref.invalidate(safetyOverviewProvider);
            },
          ),
          DabblerNavigationAction(
            icon: 'flag',
            label: 'Moderation Queue',
            onPressed: () {
              // Navigation wrapper kept as it was (non-visual route type).
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ModerationQueueScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: isAdminAsync.when(
        data: (isAdmin) {
          if (!isAdmin) return const AdminAccessDenied();

          return overviewAsync.when(
            data: (overview) => DabblerRefresh(
              onRefresh: () async {
                ref.invalidate(safetyOverviewProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(DabblerSpacing.space6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCards(overview),
                    const SizedBox(height: DabblerSpacing.space7),
                    _buildOverviewInfo(context, overview),
                  ],
                ),
              ),
            ),
            loading: () => const AdminLoading(),
            error: (error, stack) => AdminErrorState(
              title: 'Failed to load safety overview',
              text: error.toString(),
              onRetry: () {
                ref.invalidate(safetyOverviewProvider);
              },
            ),
          );
        },
        loading: () => const AdminLoading(),
        error: (error, stack) => Center(
          child: Text(
            'Failed to check admin status: $error',
            style: DabblerType.body
                .resolveForDirection(Directionality.of(context))
                .copyWith(color: DabblerColors.of(context).textPrimary),
          ),
        ),
      ),
    );
  }

  /// The four counters as a DS bento (2 x 2, each tile spanning 3 of 6).
  Widget _buildSummaryCards(SafetyOverview overview) {
    DabblerStatTile tile(String label, int value, String icon) =>
        DabblerStatTile(
          value: '$value',
          label: label,
          span: 3,
          trailing: DabblerIcon(icon, size: DabblerSizing.iconMd),
        );
    return DabblerStatGrid(
      children: [
        tile('Open Reports', overview.reportsOpen, 'flag'),
        tile('Active Enforcements', overview.activeEnforcements, 'judge'),
        tile('Active Takedowns', overview.takedownsActive, 'minus-cirlce'),
        tile('Audits (24h)', overview.audits24h, 'clock'),
      ],
    );
  }

  Widget _buildOverviewInfo(BuildContext context, SafetyOverview overview) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    return DabblerSurface.card(
      padding: const EdgeInsets.all(DabblerSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview Information',
            style: DabblerType.title3
                .resolveForDirection(Directionality.of(context))
                .copyWith(color: DabblerColors.of(context).textPrimary),
          ),
          const SizedBox(height: DabblerSpacing.space6),
          AdminInfoRow(
            label: 'Last Updated',
            value: dateFormat.format(overview.asOf),
          ),
          AdminInfoRow(label: 'Open Reports', value: '${overview.reportsOpen}'),
          AdminInfoRow(
            label: 'Active Enforcements',
            value: '${overview.activeEnforcements}',
          ),
          AdminInfoRow(
            label: 'Active Takedowns',
            value: '${overview.takedownsActive}',
          ),
          AdminInfoRow(label: 'Audits (24h)', value: '${overview.audits24h}'),
        ],
      ),
    );
  }
}
