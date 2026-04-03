import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_theme.dart';

/// Visually distinct card for system-origin posts.
///
/// Renders with the resolved [PostTheme] background (solid color, gradient,
/// or image) and styled text. Falls back to a dark default when no theme is
/// attached.
class SystemPostCard extends StatelessWidget {
  const SystemPostCard({super.key, required this.post});

  final Post post;

  // ── Default fallback theme ──────────────────────────────────────────

  static const _defaultGradientStart = Color(0xFF1E1E1E);
  static const _defaultGradientEnd = Color(0xFF2D2D2D);
  static const _defaultFontWeight = FontWeight.bold;

  // ── Helpers ─────────────────────────────────────────────────────────

  static Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) buffer.write('FF');
    buffer.write(hex);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static FontWeight _resolveFontWeight(String? style) {
    switch (style) {
      case 'bold':
        return FontWeight.bold;
      case 'italic':
        return FontWeight.w400; // italic handled separately
      default:
        return FontWeight.w400;
    }
  }

  static FontStyle _resolveFontStyle(String? style) {
    return style == 'italic' ? FontStyle.italic : FontStyle.normal;
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(dt);
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = post.postTheme;
    final tt = Theme.of(context).textTheme;

    // ── Resolve background decoration ──
    // Always gradient: use theme gradient if available, otherwise fallback.
    final Color gradStart;
    final Color gradEnd;

    if (theme != null &&
        theme.gradientStart != null &&
        theme.gradientEnd != null) {
      gradStart = _hexToColor(theme.gradientStart!);
      gradEnd = _hexToColor(theme.gradientEnd!);
    } else if (theme?.backgroundColor != null) {
      // Derive a subtle gradient from the solid color.
      gradStart = _hexToColor(theme!.backgroundColor!);
      gradEnd = Color.lerp(gradStart, Colors.black, 0.15)!;
    } else {
      gradStart = _defaultGradientStart;
      gradEnd = _defaultGradientEnd;
    }

    final decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradStart, gradEnd],
      ),
      borderRadius: BorderRadius.circular(16),
      image:
          (theme != null &&
              theme.backgroundType == 'image' &&
              theme.imageUrl != null)
          ? DecorationImage(
              image: NetworkImage(theme.imageUrl!),
              fit: BoxFit.cover,
            )
          : null,
    );

    // ── Resolve font style ──
    final fontWeight = theme != null
        ? _resolveFontWeight(theme.fontStyle)
        : _defaultFontWeight;
    final fontStyle = theme != null
        ? _resolveFontStyle(theme.fontStyle)
        : FontStyle.normal;

    final timeAgo = _relativeTime(post.createdAt);
    final chipLabel = (post.sport != null && post.sport!.trim().isNotEmpty)
        ? post.sport!
        : 'General';

    return Container(
      margin: const EdgeInsets.all(AppSpacing.sm),
      decoration: decoration,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: icon + "System" label + time ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  chipLabel,
                  style: tt.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                timeAgo,
                style: tt.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),

          if (post.body != null && post.body!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              post.body!,
              style: tt.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: fontWeight,
                fontStyle: fontStyle,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
