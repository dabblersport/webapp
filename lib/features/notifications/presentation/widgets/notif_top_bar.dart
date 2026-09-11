// Extracted from notifications_screen_v2.dart by KAN-147 (pt.A of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/themes/app_theme.dart';

/// Which of the two lists the screen is showing. Moved here with [TopBar] and
/// [ModeToggle], which cannot see a library-private enum from another file.
enum ViewMode { notifications, activity }

class TopBar extends StatelessWidget {
  final String title;
  final ViewMode mode;
  final ValueChanged<ViewMode>? onModeChanged;

  const TopBar({
    super.key,
    required this.title,
    required this.mode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Row(
        children: [
          SquareIconButton(
            icon: Iconsax.arrow_left_2_copy,
            onTap: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (onModeChanged != null)
            ModeToggle(mode: mode, onChanged: onModeChanged!),
        ],
      ),
    );
  }
}

class ModeToggle extends StatelessWidget {
  final ViewMode mode;
  final ValueChanged<ViewMode> onChanged;
  const ModeToggle({super.key, required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final scheme = context.getCategoryTheme('main');
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.onSurface.withValues(alpha: 0.10),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn(
            context,
            icon: Iconsax.notification_copy,
            active: mode == ViewMode.notifications,
            color: scheme.primary,
            onTap: () => onChanged(ViewMode.notifications),
          ),
          const SizedBox(width: 2),
          _toggleBtn(
            context,
            icon: Iconsax.activity_copy,
            active: mode == ViewMode.activity,
            color: scheme.primary,
            onTap: () => onChanged(ViewMode.activity),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(
    BuildContext context, {
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = context.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 36,
        height: 34,
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const SquareIconButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cs.onSurface.withValues(alpha: 0.10),
            width: 1.5,
          ),
        ),
        child: Icon(icon, size: 22, color: cs.onSurface),
      ),
    );
  }
}
