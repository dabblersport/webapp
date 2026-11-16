import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/home/presentation/widgets/home_post_display.dart';
import 'package:dabbler/features/social/providers/active_item.dart';

/// The card's footer (`ActivityCard.dc.html`, `gap:9px`): the host's 28
/// avatar ringed 2 in the card surface (games and meetups with a host), the
/// sport chips (`gap:6px`, wrapping), each led by the sport's emoji as on the
/// home post's sport tag (CEO 2026-11-16, KAN-965), and the action pill in the
/// look's ink.
class ActiveCardFooter extends StatelessWidget {
  const ActiveCardFooter({
    super.key,
    required this.event,
    required this.sports,
    required this.action,
    required this.ink,
    this.showHost = true,
  });

  final ActiveItem event;

  /// The localised tags, each with the English name that keys its emoji.
  final List<({String label, String en})> sports;
  final String action;
  final Color ink;

  /// The host avatar (games and meetups); the KAN-967 types draw none.
  final bool showHost;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final host = showHost && event.entityKind != 'profile' && event.hasActor;
    return Row(
      children: <Widget>[
        if (host) ...<Widget>[
          DabblerAvatar(
            seed: event.actorName,
            imageUrl: event.actorAvatarUrl,
            size: DabblerAvatarSize.xs,
            ringColor: colors.surfaceCard,
          ),
          const DabblerGap.h(DabblerSpacing.space3),
        ],
        Expanded(
          child: Wrap(
            spacing: DabblerSpacing.space2,
            runSpacing: DabblerSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final s in sports)
                DabblerActivityChip(
                  label: s.label,
                  emoji: homeSportEmoji(s.en),
                ),
            ],
          ),
        ),
        const DabblerGap.h(DabblerSpacing.space3),
        DabblerActivityAction(label: action, ink: ink),
      ],
    );
  }
}
