// Extracted from notifications_screen_v2.dart by KAN-147 (pt.A of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:flutter/material.dart';
import 'package:dabbler/themes/app_theme.dart';

class ChipData {
  final String key;
  final String label;
  final IconData icon;
  final int? count;
  const ChipData(this.key, this.label, this.icon, {this.count});
}

class ChipsRow extends StatelessWidget {
  final List<ChipData> chips;
  final String activeKey;
  final ValueChanged<String> onChanged;
  const ChipsRow({
    super.key,
    required this.chips,
    required this.activeKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = chips[i];
          return NotifChip(
            data: c,
            active: c.key == activeKey,
            onTap: () => onChanged(c.key),
          );
        },
      ),
    );
  }
}

class NotifChip extends StatelessWidget {
  final ChipData data;
  final bool active;
  final VoidCallback onTap;
  const NotifChip({
    super.key,
    required this.data,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final scheme = context.getCategoryTheme('main');
    final bg = active ? scheme.primary : cs.onSurface.withValues(alpha: 0.04);
    final fg = active ? cs.onPrimary : cs.onSurface;
    final borderColor = active
        ? Colors.transparent
        : cs.onSurface.withValues(alpha: 0.10);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.33),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              data.icon,
              size: 15,
              color: active
                  ? cs.onPrimary
                  : cs.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 7),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
            if (data.count != null && data.count! > 0) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: active
                      ? cs.onPrimary.withValues(alpha: 0.22)
                      : cs.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${data.count}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
