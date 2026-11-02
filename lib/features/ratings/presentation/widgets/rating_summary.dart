import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/ratings/domain/rating_aggregate.dart';
import 'package:dabbler/features/ratings/providers/rating_aggregate_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// A player's rating aggregate on their profile (KAN-666): a star, the average,
/// "from N ratings" when the server gives N, and up to three tag chips.
///
/// Renders nothing, and takes no space, while loading, on failure, or when the
/// server returns no aggregate (below its threshold). It is display only: no
/// taps, and it never shows who rated.
class RatingSummary extends ConsumerWidget {
  const RatingSummary({super.key, required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    if (id == null) return const SizedBox.shrink();
    final aggregate = ref.watch(ratingAggregateProvider(id)).valueOrNull;
    if (aggregate == null) return const SizedBox.shrink();
    return RatingSummaryView(aggregate: aggregate);
  }
}

/// The block itself, given an aggregate. Includes its own bottom gap so the
/// absent case leaves no gap.
class RatingSummaryView extends StatelessWidget {
  const RatingSummaryView({super.key, required this.aggregate});

  final RatingAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final average = aggregate.average.toStringAsFixed(1);
    final count = aggregate.count;
    return Padding(
      padding: const EdgeInsets.only(bottom: DabblerSpacing.space8),
      child: Semantics(
        container: true,
        label: l10n.ratings_summary_semantics(average),
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const DabblerIcon(DabblerRating.glyph),
                    const DabblerGap.h(DabblerSpacing.space2),
                    DabblerText(average, style: DabblerType.title3),
                    if (count != null) ...[
                      const DabblerGap.h(DabblerSpacing.space3),
                      DabblerText(
                        l10n.ratings_summary_from_count(count),
                        tone: DabblerTextTone.secondary,
                      ),
                    ],
                  ],
                ),
                if (aggregate.topTags.isNotEmpty) ...[
                  const DabblerGap.v(DabblerSpacing.space4),
                  Wrap(
                    spacing: DabblerSpacing.space3,
                    runSpacing: DabblerSpacing.space3,
                    children: [
                      for (final t in aggregate.topTags)
                        DabblerChip(label: t.label(arabic)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
