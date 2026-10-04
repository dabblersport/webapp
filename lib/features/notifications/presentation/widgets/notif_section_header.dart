// Extracted from notifications_screen_v2.dart by KAN-147 (pt.A of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-420: the group header is the DS activity group header; the count (and
// optional suffix) joins the label because that header carries a label only.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

class NotifSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final String? suffix;
  const NotifSectionHeader({
    super.key,
    required this.title,
    required this.count,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final n = DabblerType.toWesternDigits('$count');
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space6,
      ),
      child: DabblerActivityGroupHeader(
        title,
        dense: true,
        count: suffix == null
            ? DabblerType.toWesternDigits(
                AppLocalizations.of(context).notif_group_count(count),
              )
            : '$n $suffix',
      ),
    );
  }
}
