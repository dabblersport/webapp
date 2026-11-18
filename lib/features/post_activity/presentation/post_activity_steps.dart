// KAN-1000 (G-02): the step bodies. The score step (two steppers and the
// side the player was on, a DabblerRadio pair) and a rating group (one
// DabblerRating per active dimension). Read-only when [onChanged] is null.
// Names are shown as entered, bidi-isolated.

import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// "4 – 3".
String scoreText(Score s) => '${s.a} – ${s.b}';

class ScoreStep extends StatelessWidget {
  const ScoreStep({
    super.key,
    required this.score,
    required this.side,
    this.finalScore,
    this.onScore,
    this.onSide,
  });

  final Score score;
  final String? side;

  /// Set once the result is final: the step shows it, read-only.
  final Score? finalScore;
  final ValueChanged<Score>? onScore;
  final ValueChanged<String>? onSide;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (finalScore != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DabblerText(
            l.g02_score_final(scoreText(finalScore!)),
            key: const ValueKey<String>('g02-score-final'),
            style: DabblerType.headline,
          ),
          const DabblerGap.v(DabblerSpacing.space2),
          DabblerText(l.g02_score_locked, tone: DabblerTextTone.secondary),
        ],
      );
    }
    final edit = onScore != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DabblerText(l.g02_score_hint, tone: DabblerTextTone.secondary),
        const DabblerGap.v(DabblerSpacing.space4),
        DabblerStepper(
          key: const ValueKey<String>('g02-score-a'),
          label: l.g02_side_a,
          value: score.a,
          max: 999,
          disabled: !edit,
          onChanged: edit ? (v) => onScore!(Score(v, score.b)) : null,
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        DabblerStepper(
          key: const ValueKey<String>('g02-score-b'),
          label: l.g02_side_b,
          value: score.b,
          max: 999,
          disabled: !edit,
          onChanged: edit ? (v) => onScore!(Score(score.a, v)) : null,
        ),
        const DabblerGap.v(DabblerSpacing.space5),
        DabblerText(l.g02_my_side, weight: DabblerTextWeight.semibold),
        const DabblerGap.v(DabblerSpacing.space2),
        for (final s in const ['a', 'b'])
          Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: DabblerSpacing.space2,
            ),
            child: DabblerRadio(
              key: ValueKey<String>('g02-side-$s'),
              selected: side == s,
              disabled: onSide == null,
              label: s == 'a' ? l.g02_side_a : l.g02_side_b,
              onChanged: onSide == null ? null : (_) => onSide!(s),
            ),
          ),
      ],
    );
  }
}

/// One target's ratings: its name, then a star row per dimension.
class RatingGroup extends StatelessWidget {
  const RatingGroup({
    super.key,
    required this.id,
    required this.name,
    required this.dims,
    required this.values,
    this.onChanged,
  });

  /// The target key (`player:<id>`, `organiser`, `venue`).
  final String id;
  final String name;
  final List<RatingDimension> dims;
  final Map<String, int> values;
  final void Function(String dim, int value)? onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DabblerText(context.isolate(name), style: DabblerType.headline),
          const DabblerGap.v(DabblerSpacing.space2),
          for (final d in dims)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: DabblerSpacing.space2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DabblerText(
                      d.label(lang),
                      tone: DabblerTextTone.secondary,
                    ),
                  ),
                  DabblerRating(
                    key: ValueKey<String>('rating-$id-${d.key}'),
                    value: (values[d.key] ?? 0).toDouble(),
                    label: d.label(lang),
                    onChanged: onChanged == null
                        ? null
                        : (v) => onChanged!(d.key, v),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
