import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const EdgeInsetsDirectional kSportGutter = EdgeInsetsDirectional.symmetric(
  horizontal: DabblerSpacing.space6,
);

/// The sport's identity block: artwork, name, formats, follower count, the
/// Follow control and Create game. It scrolls away; the top bar's title takes
/// over (the design system's scroll-fade) and the tabs below stay pinned.
///
/// The follower count is the RPC's global figure. It is not tappable and there
/// is no Share or More control: neither has a specified destination (KAN-622
/// records them as unresolved), so neither is drawn.
class SportHeader extends ConsumerWidget {
  const SportHeader({super.key, required this.sport, required this.counts});

  final SportInfo sport;

  /// Null while the aggregates load or when they failed: no count is drawn.
  final SportOverviewCounts? counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    final bool following = ref.watch(
      profileControllerProvider.select(
        (s) => s.profile?.interests?.contains(sport.id) ?? false,
      ),
    );
    final SportFollowState follow = ref.watch(sportFollowControllerProvider);
    final bool canCreate = canCreateGameOrMeetup(
      ref.watch(activePersonaProvider),
    );
    final List<String> formats = sport
        .formats(lang)
        .where((String f) => f.trim().isNotEmpty)
        .toList();
    final List<String> mutual = <String>[
      for (final MutualFollower m in counts?.mutualFollowers ?? const [])
        if (m.label != null) m.label!,
    ];

    return Padding(
      padding: kSportGutter.add(
        const EdgeInsetsDirectional.only(top: DabblerSpacing.space4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DabblerSurface.sunken(
                width: DabblerSizing.tileLg,
                height: DabblerSizing.tileLg,
                radius: DabblerRadius.lg,
                center: true,
                child: sport.sportKey == null
                    ? null
                    : DabblerSportIcon.fromKey(
                        sport.sportKey!,
                        size: DabblerSizing.iconXl,
                        semanticLabel: sport.name(lang),
                      ),
              ),
              const DabblerGap.h(DabblerSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DabblerText(
                      sport.name(lang),
                      style: DabblerType.title2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (formats.isNotEmpty)
                      DabblerText(
                        formats.join(' · '),
                        style: DabblerType.footnote,
                        tone: DabblerTextTone.secondary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (counts != null)
                      DabblerText(
                        l.sport_overview_followers(counts!.followers),
                        style: DabblerType.footnote,
                        tone: DabblerTextTone.secondary,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const DabblerGap.v(DabblerSpacing.space4),
          Row(
            children: <Widget>[
              Expanded(
                child: DabblerButton(
                  label: following
                      ? l.sport_overview_following
                      : l.sport_overview_follow,
                  tone: following
                      ? DabblerButtonTone.neutral
                      : DabblerButtonTone.primary,
                  fullWidth: true,
                  loading: follow.busy,
                  onPressed: () => ref
                      .read(sportFollowControllerProvider.notifier)
                      .toggle(sport),
                ),
              ),
              if (canCreate) ...<Widget>[
                const DabblerGap.h(DabblerSpacing.space3),
                Expanded(
                  child: DabblerButton(
                    label: l.sport_overview_create_game,
                    tone: DabblerButtonTone.secondary,
                    fullWidth: true,
                    onPressed: () => context.push(
                      '${RoutePaths.createGame}?sport=${Uri.encodeQueryComponent(sport.id)}',
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (mutual.isNotEmpty) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space3),
            DabblerText(
              switch (mutual.length) {
                1 => l.sport_overview_mutual_one(mutual[0]),
                2 => l.sport_overview_mutual_two(mutual[0], mutual[1]),
                _ => l.sport_overview_mutual_three(
                  mutual[0],
                  mutual[1],
                  mutual[2],
                ),
              },
              style: DabblerType.footnote,
              tone: DabblerTextTone.secondary,
            ),
          ],
        ],
      ),
    );
  }
}
