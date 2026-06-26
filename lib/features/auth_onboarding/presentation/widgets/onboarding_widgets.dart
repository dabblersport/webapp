import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────

const Color kObBg = Color(0xFFFEF7FF);
const Color kObOnBg = Color(0xFF1D1A20);
const Color kObMuted = Color(0xFF6E6680);
const Color kObSurface = Color(0xFFFFFFFF);
const Color kObSurfaceContainer = Color(0xFFF3ECF4);
const Color kObSurfaceContainerHigh = Color(0xFFEDE6EE);
const Color kObOutline = Color(0xFFCBC4CF);
const Color kObOutlineVariant = Color(0xFFE7E0E8);
const Color kObPrimary = Color(0xFF7328CE);
const Color kObPrimaryDeep = Color(0xFF25005B);
const Color kObPrimaryContainer = Color(0xFFE0C7FF);
const Color kObOnPrimaryContainer = Color(0xFF523C72);
const Color kObPrimarySoft = Color(0xFFF1E5FE);
const Color kObPink = Color(0xFFFF3376);

// ── Sport accent colours ──────────────────────────────────────────────────────

const Map<String, Color> kSportColors = {
  'Football': Color(0xFF00C853),
  'Basketball': Color(0xFFFF6D00),
  'Tennis': Color(0xFFF4C430),
  'Padel': Color(0xFF66BB6A),
  'Badminton': Color(0xFF42A5F5),
  'Volleyball': Color(0xFF00B0FF),
  'Cricket': Color(0xFF8BC34A),
  'Running': Color(0xFFFF1744),
  'Swimming': Color(0xFF00BCD4),
  'Cycling': Color(0xFFE040FB),
  'Yoga': Color(0xFFFF7043),
  'Boxing': Color(0xFFB71C1C),
  'Trekking': Color(0xFF4CAF50),
  'Climbing': Color(0xFF8D6E63),
  'Surfing': Color(0xFF039BE5),
  'Skating': Color(0xFF9C27B0),
  'Golf': Color(0xFF388E3C),
  'Karting': Color(0xFFF44336),
  'Pickleball': Color(0xFFFFB300),
  'Hockey': Color(0xFFFF5722),
  'Rugby': Color(0xFF795548),
  'Frisbee': Color(0xFF26A69A),
};

const Map<String, IconData> kSportIcons = {
  'Football': Icons.sports_soccer,
  'Basketball': Icons.sports_basketball,
  'Tennis': Icons.sports_tennis,
  'Padel': Icons.sports_handball,
  'Badminton': Icons.sports_tennis,
  'Volleyball': Icons.sports_volleyball,
  'Cricket': Icons.sports_cricket,
  'Running': Icons.directions_run,
  'Swimming': Icons.pool,
  'Cycling': Icons.directions_bike,
  'Yoga': Icons.self_improvement,
  'Boxing': Icons.sports_mma,
  'Trekking': Icons.hiking,
  'Climbing': Icons.landscape,
  'Surfing': Icons.surfing,
  'Skating': Icons.skateboarding,
  'Golf': Icons.sports_golf,
  'Karting': Icons.sports_motorsports,
  'Pickleball': Icons.sports_tennis,
  'Hockey': Icons.sports_hockey,
  'Rugby': Icons.sports_rugby,
  'Frisbee': Icons.sports,
};

// ── Shared widgets ─────────────────────────────────────────────────────────────

/// Eyebrow pill + oversized title + subtitle
class OnboardingScreenHead extends StatelessWidget {
  const OnboardingScreenHead({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    eyebrow!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.4,
              color: colorScheme.onSurface,
              height: 1.05,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Primary pill CTA button
class OnboardingCTAButton extends StatelessWidget {
  const OnboardingCTAButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: disabled
              ? colorScheme.primaryFixedDim.withValues(alpha: 0.3)
              : colorScheme.primary,
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: disabled ? const Color(0x1F1D1A20) : colorScheme.primary,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: disabled || isLoading ? null : onPressed,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[icon!, const SizedBox(width: 8)],
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                            leadingDistribution: TextLeadingDistribution.even,
                            color: disabled
                                ? colorScheme.onPrimaryFixed.withValues(
                                    alpha: 0.4,
                                  )
                                : colorScheme.onPrimary,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SafeArea bottom bar that holds the primary CTA
class OnboardingBottomBar extends StatelessWidget {
  const OnboardingBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: child,
      ),
    );
  }
}

/// Back circle button + optional skip
class OnboardingTopBar extends StatelessWidget {
  const OnboardingTopBar({
    super.key,
    this.onBack,
    this.onSkip,
    this.showSkip = false,
  });

  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final bool showSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (onBack != null)
            _CircleIconButton(icon: Icons.arrow_back, onTap: onBack!)
          else
            const SizedBox(width: 40),
          if (showSkip && onSkip != null)
            TextButton(
              onPressed: onSkip,
              child: Text(
                'Skip',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Iconsax.arrow_left_copy,
          size: 24,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Glassmorphic frosted-glass card
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 20.0,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: colorScheme.surface.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Decorative radial gradient blob (non-interactive background element)
class GradientBlob extends StatelessWidget {
  const GradientBlob({
    super.key,
    required this.color,
    this.size = 380,
    this.opacity = 0.30,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.55),
                color.withValues(alpha: opacity * 0.18),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.30, 0.60, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient icon square used in cards/rows
class GradientIconSquare extends StatelessWidget {
  const GradientIconSquare({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48.0,
    this.radius = 14.0,
    this.iconSize = 26.0,
    this.secondColor,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double radius;
  final double iconSize;
  final Color? secondColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, secondColor ?? color.withValues(alpha: 0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
  }
}

/// Animated selection check badge
class CheckBadge extends StatelessWidget {
  const CheckBadge({super.key, required this.color, this.size = 20.0});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.check, size: size * 0.65, color: Colors.white),
    );
  }
}

/// Glass language/country pill
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: colorScheme.surface.withValues(alpha: 0.7),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
