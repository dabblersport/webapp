import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/core/widgets/loading_widget.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAdminAsync = ref.watch(isAdminProvider);
    final overviewAsync = ref.watch(safetyOverviewProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Safety Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(safetyOverviewProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ModerationQueueScreen(),
                ),
              );
            },
            tooltip: 'Moderation Queue',
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

          return overviewAsync.when(
            data: (overview) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(safetyOverviewProvider);
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(context, theme, colorScheme, overview),
                    const SizedBox(height: 24),
                    _buildOverviewInfo(context, theme, colorScheme, overview),
                  ],
                ),
              ),
            ),
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
                      'Failed to load safety overview',
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
                        ref.invalidate(safetyOverviewProvider);
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

  Widget _buildSummaryCards(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    SafetyOverview overview,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          context,
          theme,
          colorScheme,
          'Open Reports',
          '${overview.reportsOpen}',
          Icons.flag_outlined,
          colorScheme.primary,
        ),
        _buildStatCard(
          context,
          theme,
          colorScheme,
          'Active Enforcements',
          '${overview.activeEnforcements}',
          Icons.gavel,
          colorScheme.secondary,
        ),
        _buildStatCard(
          context,
          theme,
          colorScheme,
          'Active Takedowns',
          '${overview.takedownsActive}',
          Icons.remove_circle_outline,
          colorScheme.error,
        ),
        _buildStatCard(
          context,
          theme,
          colorScheme,
          'Audits (24h)',
          '${overview.audits24h}',
          Icons.history,
          colorScheme.tertiary,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Icon(icon, color: color, size: 24)],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewInfo(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    SafetyOverview overview,
  ) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview Information',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              theme,
              colorScheme,
              'Last Updated',
              dateFormat.format(overview.asOf),
            ),
            _buildInfoRow(
              theme,
              colorScheme,
              'Open Reports',
              '${overview.reportsOpen}',
            ),
            _buildInfoRow(
              theme,
              colorScheme,
              'Active Enforcements',
              '${overview.activeEnforcements}',
            ),
            _buildInfoRow(
              theme,
              colorScheme,
              'Active Takedowns',
              '${overview.takedownsActive}',
            ),
            _buildInfoRow(
              theme,
              colorScheme,
              'Audits (24h)',
              '${overview.audits24h}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    ColorScheme colorScheme,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
