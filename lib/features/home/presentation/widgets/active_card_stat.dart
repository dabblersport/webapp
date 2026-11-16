import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/social/providers/active_item.dart';
import 'package:dabbler/l10n/app_localizations.dart';

import 'active_card_look.dart';

/// KAN-964: the Active card's stat block (`ActivityCard.dc.html` `hasStat`,
/// `actCard` `statText` / `hasBar`): on the card surface, a glyph in the
/// look's ink and the count, and for an upcoming or live game with a
/// capacity the capacity bar.
///
/// | look | line | bar |
/// |---|---|---|
/// | upcoming / live game, capacity | `6/14 players · 8 spots left` (`· Full`) | yes |
/// | upcoming / live game, open | `6 players` | no |
/// | finished game | `10 played` | no |
/// | upcoming / live meetup | `9 going` | no |
/// | finished meetup | `14 went` | no |
///
/// Null when there is nothing to count (`participant_count` is null, or the
/// row is a player or a venue).
class ActiveCardStat extends StatelessWidget {
  const ActiveCardStat._({
    required this.text,
    required this.done,
    required this.ink,
    this.fraction,
    this.live = false,
  });

  /// The stat block for [event] in [look], or null.
  static ActiveCardStat? of(
    AppLocalizations l,
    ActiveItem event,
    ActiveLook look,
    Color ink,
  ) {
    final count = event.participantCount;
    if (count == null || !event.isEvent) return null;
    final meetup = event.entityKind == 'meetup';
    if (look.isFinished) {
      return ActiveCardStat._(
        text: meetup ? l.act_stat_went(count) : l.act_stat_played(count),
        done: true,
        ink: ink,
      );
    }
    if (meetup) {
      return ActiveCardStat._(
        text: l.act_stat_going(count),
        done: false,
        ink: ink,
      );
    }
    final cap = event.capacity;
    if (cap == null || cap <= 0) {
      return ActiveCardStat._(
        text: l.act_stat_players(count),
        done: false,
        ink: ink,
      );
    }
    final left = cap - count;
    return ActiveCardStat._(
      text: <String>[
        l.act_stat_players_of(count, cap),
        left > 0 ? l.act_stat_spots_left(left) : l.act_stat_full,
      ].join(' · '),
      done: false,
      ink: ink,
      fraction: count / cap,
      live: look.isLive,
    );
  }

  final String text;

  /// A finished event: the tick glyph instead of people.
  final bool done;
  final Color ink;

  /// The capacity bar's fill, or null for no bar.
  final double? fraction;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final bar = fraction;
    return DabblerSurface.sunken(
      key: const ValueKey<String>('active-card-stat'),
      radius: DabblerRadius.lg,
      fill: colors.surfaceCard,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space4,
        vertical: DabblerSpacing.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              DabblerIcon(
                done ? 'tick-circle' : 'people',
                size: DabblerHomeFrame.searchFieldGlyph,
                weight: DabblerIconWeight.bold,
                color: ink,
              ),
              const DabblerGap.h(DabblerSpacing.space2),
              Expanded(
                child: DabblerText(
                  text,
                  style: DabblerType.footnote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (bar != null) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space2),
            // The design's bar is the look's ink over its pastel; the
            // package bar is brand or status over `bgTertiary`.
            DabblerProgressBar(
              key: const ValueKey<String>('active-card-bar'),
              value: bar,
              tone: live
                  ? DabblerProgressBarTone.success
                  : DabblerProgressBarTone.brand,
            ),
          ],
        ],
      ),
    );
  }
}
