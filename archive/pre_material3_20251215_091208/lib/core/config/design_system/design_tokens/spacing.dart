import 'package:flutter/material.dart';

/// Spacing tokens following 8pt grid system with responsive scaling
class DabblerSpacing {
  // Base Spacing Units (in logical pixels)
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;
  static const double spacing64 = 64.0;

  // Responsive Multipliers
  static const double _mobileMultiplier = 1.0;
  static const double _tabletMultiplier = 1.25;
  static const double _desktopMultiplier = 1.5;

  // EdgeInsets Helpers - All
  static EdgeInsets all4 = const EdgeInsets.all(spacing4);
  static EdgeInsets all8 = const EdgeInsets.all(spacing8);
  static EdgeInsets all12 = const EdgeInsets.all(spacing12);
  static EdgeInsets all16 = const EdgeInsets.all(spacing16);
  static EdgeInsets all24 = const EdgeInsets.all(spacing24);
  static EdgeInsets all32 = const EdgeInsets.all(spacing32);
  static EdgeInsets all48 = const EdgeInsets.all(spacing48);
  static EdgeInsets all64 = const EdgeInsets.all(spacing64);

  // EdgeInsets Helpers - Symmetric Horizontal
  static EdgeInsets horizontal4 = const EdgeInsets.symmetric(
    horizontal: spacing4,
  );
  static EdgeInsets horizontal8 = const EdgeInsets.symmetric(
    horizontal: spacing8,
  );
  static EdgeInsets horizontal12 = const EdgeInsets.symmetric(
    horizontal: spacing12,
  );
  static EdgeInsets horizontal16 = const EdgeInsets.symmetric(
    horizontal: spacing16,
  );
  static EdgeInsets horizontal24 = const EdgeInsets.symmetric(
    horizontal: spacing24,
  );
  static EdgeInsets horizontal32 = const EdgeInsets.symmetric(
    horizontal: spacing32,
  );
  static EdgeInsets horizontal48 = const EdgeInsets.symmetric(
    horizontal: spacing48,
  );
  static EdgeInsets horizontal64 = const EdgeInsets.symmetric(
    horizontal: spacing64,
  );

  // EdgeInsets Helpers - Symmetric Vertical
  static EdgeInsets vertical4 = const EdgeInsets.symmetric(vertical: spacing4);
  static EdgeInsets vertical8 = const EdgeInsets.symmetric(vertical: spacing8);
  static EdgeInsets vertical12 = const EdgeInsets.symmetric(
    vertical: spacing12,
  );
  static EdgeInsets vertical16 = const EdgeInsets.symmetric(
    vertical: spacing16,
  );
  static EdgeInsets vertical24 = const EdgeInsets.symmetric(
    vertical: spacing24,
  );
  static EdgeInsets vertical32 = const EdgeInsets.symmetric(
    vertical: spacing32,
  );
  static EdgeInsets vertical48 = const EdgeInsets.symmetric(
    vertical: spacing48,
  );
  static EdgeInsets vertical64 = const EdgeInsets.symmetric(
    vertical: spacing64,
  );

  // Helper Methods
  static double getResponsiveSpacing(double baseSpacing, BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    double multiplier = _mobileMultiplier;

    if (width >= 992) {
      multiplier = _desktopMultiplier;
    } else if (width >= 576) {
      multiplier = _tabletMultiplier;
    }

    return baseSpacing * multiplier;
  }

  static EdgeInsets getResponsiveInsets(
    EdgeInsets baseInsets,
    BuildContext context,
  ) {
    final double multiplier = _getMultiplierForContext(context);

    return EdgeInsets.only(
      left: baseInsets.left * multiplier,
      top: baseInsets.top * multiplier,
      right: baseInsets.right * multiplier,
      bottom: baseInsets.bottom * multiplier,
    );
  }

  // Private Helper Method
  static double _getMultiplierForContext(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    if (width >= 992) {
      return _desktopMultiplier;
    } else if (width >= 576) {
      return _tabletMultiplier;
    }

    return _mobileMultiplier;
  }

  // Custom Spacing Generator
  static EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(left: left, top: top, right: right, bottom: bottom);
  }

  // Stack Spacing (for use with Positioned widget)
  static const stackSpacing = {
    'xxs': 2.0,
    'xs': spacing4,
    'sm': spacing8,
    'md': spacing16,
    'lg': spacing24,
    'xl': spacing32,
    'xxl': spacing48,
  };
}
