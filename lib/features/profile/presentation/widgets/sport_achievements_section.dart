import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
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
          icon: 'cup',
          message: 'No sport achievements yet.',
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SportAchievementsData data) {
    if (data.badges.isEmpty && data.recentEvents.isEmpty) {
      return const SportEmptySection(
        icon: 'cup',
        message: 'No sport achievements yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.badges.isNotEmpty)
          Wrap(
            spacing: DabblerSpacing.space2,
            runSpacing: DabblerSpacing.space2,
            children: data.badges
                .map(
                  (badge) => DabblerBadge(
                    label: badge.name.isEmpty ? badge.key : badge.name,
                    tone: DabblerBadgeTone.defaultTone,
                  ),
                )
                .toList(),
          ),
        if (data.badges.isNotEmpty && data.recentEvents.isNotEmpty)
          const DabblerGap.v(DabblerSpacing.space5),
        if (data.recentEvents.isNotEmpty)
          ...data.recentEvents.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: DabblerSpacing.space3),
              child: Row(
                children: [
                  const DabblerIconTile.named('medal-star'),
                  const DabblerGap.h(DabblerSpacing.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DabblerText(
                          _formatEventType(event.eventType),
                          style: DabblerType.subheadline,
                          weight: DabblerTextWeight.semibold,
                        ),
                        DabblerText(
                          _formatEventData(event.eventData),
                          style: DabblerType.footnote,
                          tone: DabblerTextTone.secondary,
                        ),
                      ],
                    ),
                  ),
                ],
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
