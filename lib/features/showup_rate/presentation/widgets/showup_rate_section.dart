import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/showup_rate/domain/showup_rate.dart';
import 'package:dabbler/features/showup_rate/providers/showup_rate_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The show-up rate on a profile (G-07, KAN-1001), read from the server.
/// Renders nothing while loading or when the read fails.
class ShowUpRateSection extends ConsumerWidget {
  const ShowUpRateSection({super.key, required this.userId, this.own = false});

  final String? userId;

  /// The viewer's own profile: adds "How it's counted".
  final bool own;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    if (id == null) return const SizedBox.shrink();
    final rate = ref.watch(showUpRateProvider(id)).valueOrNull;
    if (rate == null) return const SizedBox.shrink();
    return ShowUpRateView(rate: rate, own: own);
  }
}

/// The block itself, given the server's rate. Includes its own bottom gap so
/// the absent case leaves no gap.
class ShowUpRateView extends StatefulWidget {
  const ShowUpRateView({super.key, required this.rate, this.own = false});

  final ShowUpRate rate;
  final bool own;

  @override
  State<ShowUpRateView> createState() => _ShowUpRateViewState();
}

class _ShowUpRateViewState extends State<ShowUpRateView> {
  bool _explained = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ShowUpRate r = widget.rate;
    final int? percent = r.enough ? r.rate : null;
    return Padding(
      // Same horizontal inset as the neighbouring profile sections.
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space6,
        end: DabblerSpacing.space6,
        bottom: DabblerSpacing.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DabblerText(l10n.showup_rate_title, tone: DabblerTextTone.secondary),
          const DabblerGap.v(DabblerSpacing.space2),
          if (percent == null)
            DabblerText(l10n.showup_rate_not_enough)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DabblerText(
                  l10n.showup_rate_percent(percent),
                  style: DabblerType.title3,
                ),
                const DabblerGap.h(DabblerSpacing.space3),
                Flexible(
                  child: DabblerText(
                    l10n.showup_rate_basis(r.confirmed),
                    tone: DabblerTextTone.secondary,
                  ),
                ),
              ],
            ),
          if (widget.own) ...[
            const DabblerGap.v(DabblerSpacing.space3),
            DabblerButton(
              label: l10n.showup_rate_how_counted,
              tone: DabblerButtonTone.neutral,
              size: DabblerButtonSize.small,
              onPressed: () => setState(() => _explained = !_explained),
            ),
            if (_explained) ...[
              const DabblerGap.v(DabblerSpacing.space3),
              DabblerText(
                l10n.showup_rate_rule,
                tone: DabblerTextTone.secondary,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
