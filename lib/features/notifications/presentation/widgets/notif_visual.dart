// Extracted from notifications_screen_v2.dart by KAN-147 (pt.A of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-420: the visual is a DS icon name plus a DS icon-tile tone. No colour is
// carried, so every tint resolves through the active design-system theme.

import 'package:dabbler_design_system/dabbler_design_system.dart';

class NotifVisual {
  /// Kebab-case Iconsax name rendered through [DabblerIcon].
  final String icon;
  final DabblerIconTileTone tone;
  const NotifVisual(this.icon, this.tone);
}
