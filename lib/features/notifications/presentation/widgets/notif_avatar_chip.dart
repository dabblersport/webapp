// Extracted from notifications_screen_v2.dart by KAN-151 (pt.B of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:flutter/material.dart';

class AvatarChip extends StatelessWidget {
  final String name;
  static const double size = 22;
  const AvatarChip({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.isEmpty
        ? '?'
        : name
            .split(RegExp(r'\s+|_'))
            .where((s) => s.isNotEmpty)
            .map((s) => s[0])
            .take(2)
            .join()
            .toUpperCase();
    final hue = (name.codeUnits.fold<int>(0, (a, b) => a + b) % 360);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue.toDouble(), 0.65, 0.55).toColor(),
            HSLColor.fromAHSL(1, ((hue + 50) % 360).toDouble(), 0.7, 0.45)
                .toColor(),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
