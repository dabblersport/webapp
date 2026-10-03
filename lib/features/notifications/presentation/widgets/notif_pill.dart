// Extracted from notifications_screen_v2.dart by KAN-147 (pt.A of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-420: a status pill is the DS badge. [status] is a DS status colour set
// (never a raw colour); null draws the neutral status.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

class Pill extends StatelessWidget {
  final String label;
  final DabblerStatusColor? status;
  const Pill({super.key, required this.label, this.status});

  @override
  Widget build(BuildContext context) {
    return DabblerBadge(
      label: label,
      status: status ?? DabblerBadge.neutralStatusOf(DabblerColors.of(context)),
    );
  }
}
