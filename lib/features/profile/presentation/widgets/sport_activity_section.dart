import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profile_view_provider.dart';
import 'package:dabbler/features/profile/presentation/widgets/sport_profile_section_widgets.dart';
import 'package:dabbler/features/social/presentation/widgets/feed_post_card.dart';

/// "Sport Activity" card: posts the user authored/commented/reacted for this
/// sport, loaded independently of the rest of the sport profile screen.
class SportActivitySection extends ConsumerWidget {
  const SportActivitySection({super.key, required this.args});

  final SportProfileRouteArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final activityAsync = ref.watch(sportActivityProvider(args));

    return SportSectionCard(
      title: 'Sport Activity',
      child: activityAsync.when(
        loading: () => const SportSectionLoading(),
        error: (_, _) => const SportEmptySection(
          icon: Icons.article_outlined,
          message: 'No sport-related posts yet.',
        ),
        data: (activity) => activity.isEmpty
            ? const SportEmptySection(
                icon: Icons.article_outlined,
                message: 'No sport-related posts yet.',
              )
            : Column(
                children: activity.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: item.sources
                              .map(
                                (source) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _sourceLabel(source),
                                    style: textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        FeedPostCard(post: item.post),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  static String _sourceLabel(SportActivitySource source) {
    switch (source) {
      case SportActivitySource.authored:
        return 'Authored';
      case SportActivitySource.commented:
        return 'Commented';
      case SportActivitySource.reacted:
        return 'Reacted';
    }
  }
}
