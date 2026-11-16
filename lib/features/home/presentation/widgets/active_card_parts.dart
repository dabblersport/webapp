import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/social/providers/active_item.dart';

/// The card's footer (`ActivityCard.dc.html`, `gap:9px`): the host's 28
/// avatar ringed 2 in the card surface (games and meetups with a host), the
/// sport chips (`gap:6px`, wrapping) and the action pill in the look's ink.
class ActiveCardFooter extends StatelessWidget {
  const ActiveCardFooter({
    super.key,
    required this.event,
    required this.sports,
    required this.action,
    required this.ink,
  });

  final ActiveItem event;
  final List<String> sports;
  final String action;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final host = event.entityKind != 'profile' && event.hasActor;
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
              for (final s in sports) DabblerActivityChip(label: s),
            ],
          ),
        ),
        const DabblerGap.h(DabblerSpacing.space3),
        DabblerActivityAction(label: action, ink: ink),
      ],
    );
  }
}
