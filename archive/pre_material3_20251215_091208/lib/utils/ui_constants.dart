/// UI Constants for consistent spacing, sizing, and styling across the app
library;

import 'package:flutter/material.dart';

/// Spacing constants following 4px base unit
class AppSpacing {
  // Base unit
  static const double baseUnit = 4.0;

  // Common spacing values
  static const double xs = baseUnit; // 4px
  static const double sm = baseUnit * 2; // 8px
  static const double md = baseUnit * 3; // 12px
  static const double lg = baseUnit * 4; // 16px
  static const double xl = baseUnit * 5; // 20px
  static const double xxl = baseUnit * 6; // 24px
  static const double xxxl = baseUnit * 8; // 32px

  // Screen padding
  static const double screenPaddingHorizontal = lg;
  static const double screenPaddingVertical = lg;
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenPaddingHorizontal,
    vertical: screenPaddingVertical,
  );

  // Card padding
  static const double cardPadding = lg;
  static const EdgeInsets cardPaddingAll = EdgeInsets.all(cardPadding);

  // Section spacing
  static const double sectionSpacing = xl;

  // Item spacing in lists
  static const double listItemSpacing = md;
}

/// Border radius constants
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double full = 999.0;

  // Common border radius
  static BorderRadius get small => BorderRadius.circular(sm);
  static BorderRadius get medium => BorderRadius.circular(md);
  static BorderRadius get large => BorderRadius.circular(lg);
  static BorderRadius get extraLarge => BorderRadius.circular(xl);
  static BorderRadius get extraExtraLarge => BorderRadius.circular(xxl);
  static BorderRadius get circular => BorderRadius.circular(full);
}

/// Elevation/Shadow constants
class AppElevation {
  static const double none = 0;
  static const double sm = 2;
  static const double md = 4;
  static const double lg = 8;
  static const double xl = 16;

  /// Create a subtle shadow for cards
  static List<BoxShadow> cardShadow(
    BuildContext context, {
    double opacity = 0.08,
  }) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 12,
        offset: const Offset(0, 4),
        spreadRadius: 0,
      ),
    ];
  }

  /// Create an elevated shadow
  static List<BoxShadow> elevatedShadow(
    BuildContext context, {
    double opacity = 0.12,
  }) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 20,
        offset: const Offset(0, 8),
        spreadRadius: 0,
      ),
    ];
  }
}

/// Icon size constants
class AppIconSize {
  static const double xs = 16.0;
  static const double sm = 20.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double xl = 40.0;
  static const double xxl = 48.0;
}

/// Animation duration constants
class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration verySlow = Duration(milliseconds: 500);
}

/// Common curves for animations
class AppCurves {
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve spring = Curves.elasticOut;
}

/// Button size constants
class AppButtonSize {
  // Heights
  static const double smallHeight = 36.0;
  static const double mediumHeight = 44.0;
  static const double largeHeight = 52.0;

  // Padding
  static const EdgeInsets smallPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );
  static const EdgeInsets mediumPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );
  static const EdgeInsets largePadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 14,
  );
}
