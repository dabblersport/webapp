// Extracted from notifications_screen_v2.dart by KAN-152 (pt.C of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-420: a success DabblerBanner. The "Manage devices" text was inert emphasis
// at the end of the body; it now ends the message (the banner takes plain text).

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class ActivitySecurityFooter extends StatelessWidget {
  const ActivitySecurityFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        DabblerSpacing.space4,
        DabblerSpacing.space6,
        DabblerSpacing.space4,
      ),
      child: DabblerBanner(
        tone: DabblerBannerTone.success,
        icon: const DabblerIcon('security'),
        title: l10n.activity_all_normal_title,
        // The l10n string ends in an arrow glyph the DS faces do not carry
        // (it draws as a missing-glyph box); the text link is inert anyway.
        message:
            '${l10n.activity_all_normal_body}${l10n.activity_manage_devices.replaceAll('→', '').trim()}',
      ),
    );
  }
}
