// Extracted from notifications_screen_v2.dart by KAN-147 (pt.A of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:flutter/material.dart';
import 'package:dabbler/themes/app_theme.dart';

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
    final cs = context.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.45);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: muted,
              ),
            ),
          ),
          Text(
            suffix == null ? '$count' : '$count $suffix',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}
