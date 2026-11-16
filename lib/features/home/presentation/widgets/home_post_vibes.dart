import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/data/models/social/vibe.dart';

/// KAN-963: the vibes people added to a post, as the chips under the post.
///
/// A post's `reaction_breakdown` is `{"breakdown": {<vibe key>: <count>}}`. A
/// viewer holds at most one vibe on a post (the reactions table is unique on
/// post and user), so joining a vibe moves the viewer off any other one.

/// The breakdown as vibe key -> count, counts above zero only, in its order.
Map<String, int> homeVibeCounts(Map<String, dynamic> reactionBreakdown) {
  final Object? raw = reactionBreakdown['breakdown'];
  if (raw is! Map) return <String, int>{};
  return <String, int>{
    for (final MapEntry<dynamic, dynamic> e in raw.entries)
      if (e.value is int && (e.value as int) > 0)
        e.key.toString(): e.value as int,
  };
}

/// The tally after the viewer taps [key]: leaving it when it is theirs (-1),
/// otherwise joining it (+1) and leaving the vibe they held before. A vibe at
/// zero is dropped, so its chip disappears.
({Map<String, int> counts, Set<String> mine}) homeVibeToggle(
  Map<String, int> counts,
  Set<String> mine,
  String key,
) {
  final Map<String, int> next = Map<String, int>.of(counts);
  void bump(String k, int by) {
    final int n = (next[k] ?? 0) + by;
    if (n > 0) {
      next[k] = n;
    } else {
      next.remove(k);
    }
  }

  if (mine.contains(key)) {
    bump(key, -1);
    return (counts: next, mine: <String>{});
  }
  for (final String held in mine) {
    bump(held, -1);
  }
  bump(key, 1);
  return (counts: next, mine: <String>{key});
}

/// A vibe's label in the viewer's language; the key when it is unknown.
String homeVibeLabel(BuildContext context, Vibe? vibe, String key) {
  if (vibe == null) return key;
  final bool ar = Localizations.localeOf(context).languageCode == 'ar';
  if (ar && vibe.labelAr.isNotEmpty) return vibe.labelAr;
  return vibe.labelEn.isNotEmpty ? vibe.labelEn : vibe.key;
}

/// The chips: one per vibe with a count, "Inspired 3", the viewer's own in
/// the selected (brand) state and the rest outlined. Tapping one calls
/// [onToggle] with its vibe; a key the vibe list does not know is inert.
class HomeVibeChips extends StatelessWidget {
  const HomeVibeChips({
    super.key,
    required this.counts,
    required this.mine,
    required this.vibes,
    required this.onToggle,
    this.metrics = DabblerFeedMetrics.touch,
  });

  final Map<String, int> counts;

  /// The vibe keys the viewer holds.
  final Set<String> mine;
  final List<Vibe> vibes;
  final ValueChanged<Vibe> onToggle;
  final DabblerFeedMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DabblerSpacing.space2,
      runSpacing: DabblerSpacing.space2,
      children: <Widget>[
        for (final MapEntry<String, int> e in counts.entries)
          Builder(
            builder: (context) {
              final Vibe? vibe = vibes.where((v) => v.key == e.key).firstOrNull;
              return DabblerChip(
                key: ValueKey<String>('home-vibe-chip-${e.key}'),
                label: '${homeVibeLabel(context, vibe, e.key)} ${e.value}',
                selected: mine.contains(e.key),
                dense: true,
                labelWeight: DabblerType.regular,
                metrics: metrics,
                compactHitArea: true,
                onTap: vibe == null ? null : () => onToggle(vibe),
              );
            },
          ),
      ],
    );
  }
}
