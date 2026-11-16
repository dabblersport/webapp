import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/social/providers/active_item.dart';

import 'active_card_look.dart';

/// Text in an ink the type tones do not name (a look's tone ink).
class ActiveInked extends StatelessWidget {
  const ActiveInked({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: DefaultTextStyle.of(context).style.copyWith(color: color),
    child: child,
  );
}

/// The kicker pill: on the card surface, the family glyph and the kicker in
/// the look's ink, or while live the green dot and the kicker in the success
/// ink (`ActivityCard.dc.html`, 11/13, `padding:4px 10px 4px 8px`).
class ActiveKickerPill extends StatelessWidget {
  const ActiveKickerPill({
    super.key,
    required this.look,
    required this.label,
    required this.ink,
  });

  final ActiveLook look;
  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DabblerSurface.sunken(
        radius: DabblerRadius.pill,
        fill: colors.surfaceCard,
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerHomeFrame.postBadgePaddingInline,
          DabblerSpacing.space1,
          DabblerSpacing.space3,
          DabblerSpacing.space1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (look.isLive) ...<Widget>[
              DabblerSurface.sunken(
                key: const ValueKey<String>('active-live-dot'),
                width: DabblerSpacing.space2,
                height: DabblerSpacing.space2,
                radius: DabblerRadius.pill,
                fill: colors.success.base,
              ),
              const DabblerGap.h(DabblerSpacing.space2),
            ] else ...<Widget>[
              DabblerIcon(
                look.familyIcon,
                size: DabblerSpacing.space4,
                weight: DabblerIconWeight.bold,
                color: ink,
              ),
              const SizedBox(width: DabblerHomeFrame.postMetaGap),
            ],
            Flexible(
              child: look.isLive
                  ? DabblerText(
                      label,
                      style: DabblerType.caption2,
                      tone: DabblerTextTone.success,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : ActiveInked(
                      color: ink,
                      child: DabblerText(
                        label,
                        style: DabblerType.caption2,
                        tone: DabblerTextTone.inherit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The host's 28 avatar (games, meetups), the sport tags and the action pill
/// in the look's ink.
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
            children: <Widget>[
              for (final s in sports)
                DabblerSurface.sunken(
                  radius: DabblerRadius.pill,
                  fill: colors.surfaceCard,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: DabblerSpacing.space3,
                    vertical: DabblerSpacing.space1,
                  ),
                  child: DabblerText(
                    s,
                    style: DabblerType.caption2,
                    tone: DabblerTextTone.secondary,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
        const DabblerGap.h(DabblerSpacing.space3),
        DabblerSurface.sunken(
          key: const ValueKey<String>('active-card-action'),
          radius: DabblerRadius.pill,
          fill: ink,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: DabblerSpacing.space6,
            vertical: DabblerSpacing.space3,
          ),
          child: ActiveInked(
            color: colors.surfaceCard,
            child: DabblerText(
              action,
              style: DabblerType.small,
              tone: DabblerTextTone.inherit,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
