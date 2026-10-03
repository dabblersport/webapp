// Extracted from notifications_screen_v2.dart by KAN-151 (pt.B of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-420: the initials chip is the DS avatar (seeded by the actor name).

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

class AvatarChip extends StatelessWidget {
  final String name;
  const AvatarChip({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return DabblerAvatar(seed: name, size: DabblerAvatarSize.xs);
  }
}
