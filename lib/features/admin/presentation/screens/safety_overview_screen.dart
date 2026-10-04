import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

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

    // One layout at every width: the Material adaptive-scaffold rail wrapper is
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
            // The router route carries the app's shared-axis transition.
            onPressed: () => context.push(RoutePaths.adminModerationQueue),
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
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: DabblerInsets.screen,
                children: [
                  _buildSummaryCards(overview),
                  const DabblerGap.v(DabblerSpacing.space7),
                  _buildOverviewInfo(context, overview),
                ],
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
          child: DabblerText(
            'Failed to check admin status: $error',
            style: DabblerType.body,
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
    DabblerKeyValueRow row(String label, String value) =>
        DabblerKeyValueRow(label: label, value: value);
    return DabblerCard(
      header: const DabblerText(
        'Overview Information',
        style: DabblerType.title3,
      ),
      child: Column(
        children: [
          row('Last Updated', dateFormat.format(overview.asOf)),
          row('Open Reports', '${overview.reportsOpen}'),
          row('Active Enforcements', '${overview.activeEnforcements}'),
          row('Active Takedowns', '${overview.takedownsActive}'),
          row('Audits (24h)', '${overview.audits24h}'),
        ],
      ),
    );
  }
}
