// Extracted from notifications_screen_v2.dart by KAN-152 (pt.C of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-420: the search box and the filter button were inert placeholders and
// still are (no handler); they are now DS controls. The field is disabled so it
// does not take focus or promise typing.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class ActivitySearchRow extends StatelessWidget {
  const ActivitySearchRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space6,
        end: DabblerSpacing.space6,
        bottom: DabblerSpacing.space3,
      ),
      child: Row(
        children: [
          Expanded(
            child: DabblerSearchField(
              placeholder: AppLocalizations.of(context).activity_search_hint,
              enabled: false,
              clearable: false,
            ),
          ),
          const SizedBox(width: DabblerSpacing.space2),
          const DabblerButton.icon(
            icon: 'filter',
            semanticLabel: 'Filter',
            tone: DabblerButtonTone.outlined,
          ),
        ],
      ),
    );
  }
}
