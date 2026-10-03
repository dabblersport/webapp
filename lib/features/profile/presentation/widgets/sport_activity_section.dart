import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profile_view_provider.dart';
import 'package:dabbler/features/profile/presentation/widgets/sport_profile_section_widgets.dart';
import 'package:dabbler/core/feed/post_layout_resolver.dart';

/// "Sport Activity" card: posts the user authored/commented/reacted for this
/// sport, loaded independently of the rest of the sport profile screen.
class SportActivitySection extends ConsumerWidget {
  const SportActivitySection({super.key, required this.args});

  final SportProfileRouteArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(sportActivityProvider(args));

    return SportSectionCard(
      title: 'Sport Activity',
      child: activityAsync.when(
        loading: () => const SportSectionLoading(),
        error: (_, _) => const SportEmptySection(
          icon: 'document-text',
          message: 'No sport-related posts yet.',
        ),
        data: (activity) => activity.isEmpty
            ? const SportEmptySection(
                icon: 'document-text',
                message: 'No sport-related posts yet.',
              )
            : Column(
                children: activity.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: DabblerSpacing.space4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: DabblerSpacing.space2,
                          runSpacing: DabblerSpacing.space2,
                          children: item.sources
                              .map(
                                (source) => DabblerBadge(
                                  label: _sourceLabel(source),
                                  tone: DabblerBadgeTone.pill,
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: DabblerSpacing.space2),
                        resolvePostLayout(item.post),
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
