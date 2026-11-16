import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/social/providers/active_item.dart';
import 'package:dabbler/l10n/app_localizations.dart';

import 'active_card_look.dart';

/// KAN-964 / KAN-965: the Active card's stat block (`ActivityCard.dc.html`
/// `hasStat`, `actCard` `statText` / `hasBar`), drawn by the package's
/// [DabblerActivityStat]: a glyph in the look's ink and the count, and for an
/// upcoming or live game with a capacity the bar in the card's tone.
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
abstract final class ActiveCardStat {
  /// The stat block for [event] in [look], or null.
  static Widget? of(AppLocalizations l, ActiveItem event, ActiveLook look) {
    final count = event.participantCount;
    if (count == null || !event.isEvent) return null;
    final meetup = event.entityKind == 'meetup';
    final String text;
    double? fraction;
    if (look.isFinished) {
      text = meetup ? l.act_stat_went(count) : l.act_stat_played(count);
    } else if (meetup) {
      text = l.act_stat_going(count);
    } else {
      final cap = event.capacity;
      if (cap == null || cap <= 0) {
        text = l.act_stat_players(count);
      } else {
        final left = cap - count;
        text = <String>[
          l.act_stat_players_of(count, cap),
          left > 0 ? l.act_stat_spots_left(left) : l.act_stat_full,
        ].join(' · ');
        fraction = count / cap;
      }
    }
    return DabblerActivityStat(
      key: const ValueKey<String>('active-card-stat'),
      icon: look.isFinished ? 'tick-circle' : 'people',
      text: text,
      tone: look.tone,
      fraction: fraction,
    );
  }
}
