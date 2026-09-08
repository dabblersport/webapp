// Extracted from notifications_screen_v2.dart by KAN-147 (pt.A of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:flutter/material.dart';

class NotifVisual {
  final IconData icon;
  final Color color;
  const NotifVisual(this.icon, this.color);
}
