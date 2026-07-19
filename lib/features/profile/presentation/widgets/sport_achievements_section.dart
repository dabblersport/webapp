import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profile_view_provider.dart';
import 'package:dabbler/features/profile/presentation/widgets/sport_profile_section_widgets.dart';

/// "Achievements" card: badges + recent sport profile events, loaded
/// independently of the rest of the sport profile screen.
class SportAchievementsSection extends ConsumerWidget {
  const SportAchievementsSection({super.key, required this.args});

  final SportProfileRouteArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(sportAchievementsProvider(args));

    return SportSectionCard(
      title: 'Achievements',
      child: achievementsAsync.when(
        data: (data) => _buildContent(context, data),
        loading: () => const SportSectionLoading(),
        error: (_, _) => const SportEmptySection(
          icon: Icons.emoji_events_outlined,
          message: 'No sport achievements yet.',
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SportAchievementsData data) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (data.badges.isEmpty && data.recentEvents.isEmpty) {
      return const SportEmptySection(
        icon: Icons.emoji_events_outlined,
        message: 'No sport achievements yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.badges.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.badges
                .map(
                  (badge) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge.name.isEmpty ? badge.key : badge.name,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        if (data.badges.isNotEmpty && data.recentEvents.isNotEmpty)
          const SizedBox(height: 16),
        if (data.recentEvents.isNotEmpty)
          ...data.recentEvents.map(
            (event) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.workspace_premium_outlined,
                color: colorScheme.primary,
              ),
              title: Text(
                _formatEventType(event.eventType),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _formatEventData(event.eventData),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _formatEventType(String type) {
    if (type.isEmpty) {
      return 'Sport milestone';
    }
    return type
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static String _formatEventData(Map<String, dynamic> eventData) {
    if (eventData.isEmpty) {
      return 'Recent progress in this sport.';
    }
    final entries = eventData.entries
        .take(2)
        .map((entry) => '${entry.key}: ${entry.value}');
    return entries.join(' • ');
  }
}
