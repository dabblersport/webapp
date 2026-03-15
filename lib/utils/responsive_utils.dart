import 'package:flutter/material.dart';

import 'package:dabbler/widgets/adaptive_scaffold.dart';

/// Returns `true` when the current viewport is wider than the compact
/// breakpoint (600 px) — i.e. the layout should show the adaptive
/// side-nav / centered-content variant.
bool isWideScreen(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= AdaptiveBreakpoints.compact;
}
