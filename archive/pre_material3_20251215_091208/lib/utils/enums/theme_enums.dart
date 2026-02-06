/// Theme and appearance enum definitions with Flutter theme integration
library;

import 'package:flutter/material.dart';

/// Enum representing different theme modes in the application
enum AppThemeMode {
  light('light', 'Light'),
  dark('dark', 'Dark'),
  system('system', 'System');

  final String value;
  final String displayName;
  const AppThemeMode(this.value, this.displayName);

  /// Create AppThemeMode from string value
  static AppThemeMode fromString(String value) => AppThemeMode.values
      .firstWhere((e) => e.value == value, orElse: () => AppThemeMode.system);

  /// Convert to Flutter's ThemeMode
  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// Get icon for this theme mode
  IconData get icon {
    switch (this) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  /// Get description for this theme mode
  String get description {
    switch (this) {
      case AppThemeMode.light:
        return 'Always use light theme';
      case AppThemeMode.dark:
        return 'Always use dark theme';
      case AppThemeMode.system:
        return 'Follow system theme settings';
    }
  }

  /// Generate a theme selector widget
  Widget toSelectorTile({
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return Card(
      elevation: selected ? 4 : 1,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: selected ? Border.all(color: Colors.blue, width: 2) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: selected ? Colors.blue : Colors.grey),
              const SizedBox(height: 8),
              Text(
                displayName,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.blue : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Enum representing different accent color options
enum AccentColor {
  blue('blue', 'Blue', Colors.blue),
  green('green', 'Green', Colors.green),
  orange('orange', 'Orange', Colors.orange),
  purple('purple', 'Purple', Colors.purple),
  red('red', 'Red', Colors.red),
  teal('teal', 'Teal', Colors.teal),
  pink('pink', 'Pink', Colors.pink),
  indigo('indigo', 'Indigo', Colors.indigo);

  final String value;
  final String displayName;
  final Color color;
  const AccentColor(this.value, this.displayName, this.color);

  /// Create AccentColor from string value
  static AccentColor fromString(String value) => AccentColor.values.firstWhere(
    (e) => e.value == value,
    orElse: () => AccentColor.blue,
  );

  /// Get Material Color swatch for theme generation
  MaterialColor get materialColor {
    switch (this) {
      case AccentColor.blue:
        return Colors.blue;
      case AccentColor.green:
        return Colors.green;
      case AccentColor.orange:
        return Colors.orange;
      case AccentColor.purple:
        return Colors.purple;
      case AccentColor.red:
        return Colors.red;
      case AccentColor.teal:
        return Colors.teal;
      case AccentColor.pink:
        return Colors.pink;
      case AccentColor.indigo:
        return Colors.indigo;
    }
  }

  /// Generate a color picker widget
  Widget toColorPicker({
    required bool selected,
    required VoidCallback onSelected,
    double size = 40,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Colors.white, width: 3)
              : Border.all(color: Colors.grey[300]!, width: 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: selected
            ? Icon(Icons.check, color: Colors.white, size: size * 0.5)
            : null,
      ),
    );
  }
}

/// Enum representing different font size options
enum FontSize {
  small('small', 'Small', 0.9),
  medium('medium', 'Medium', 1.0),
  large('large', 'Large', 1.1),
  extraLarge('extra_large', 'Extra Large', 1.2);

  final String value;
  final String displayName;
  final double scaleFactor;
  const FontSize(this.value, this.displayName, this.scaleFactor);

  /// Create FontSize from string value
  static FontSize fromString(String value) => FontSize.values.firstWhere(
    (e) => e.value == value,
    orElse: () => FontSize.medium,
  );

  /// Generate a font size preview widget
  Widget toPreview({required bool selected, required VoidCallback onSelected}) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: selected ? Colors.blue : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          displayName,
          style: TextStyle(
            fontSize: 16 * scaleFactor,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.blue : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  /// Get text theme with this font size applied
  TextTheme applyToTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: (base.displayLarge?.fontSize ?? 57) * scaleFactor,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: (base.displayMedium?.fontSize ?? 45) * scaleFactor,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: (base.displaySmall?.fontSize ?? 36) * scaleFactor,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: (base.headlineLarge?.fontSize ?? 32) * scaleFactor,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: (base.headlineMedium?.fontSize ?? 28) * scaleFactor,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: (base.headlineSmall?.fontSize ?? 24) * scaleFactor,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: (base.titleLarge?.fontSize ?? 22) * scaleFactor,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: (base.titleMedium?.fontSize ?? 16) * scaleFactor,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: (base.titleSmall?.fontSize ?? 14) * scaleFactor,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: (base.bodyLarge?.fontSize ?? 16) * scaleFactor,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: (base.bodyMedium?.fontSize ?? 14) * scaleFactor,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: (base.bodySmall?.fontSize ?? 12) * scaleFactor,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: (base.labelLarge?.fontSize ?? 14) * scaleFactor,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: (base.labelMedium?.fontSize ?? 12) * scaleFactor,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: (base.labelSmall?.fontSize ?? 11) * scaleFactor,
      ),
    );
  }
}

/// Enum representing different interface density options
enum InterfaceDensity {
  compact('compact', 'Compact', VisualDensity.compact),
  standard('standard', 'Standard', VisualDensity.standard),
  comfortable('comfortable', 'Comfortable', VisualDensity.comfortable);

  final String value;
  final String displayName;
  final VisualDensity visualDensity;
  const InterfaceDensity(this.value, this.displayName, this.visualDensity);

  /// Create InterfaceDensity from string value
  static InterfaceDensity fromString(String value) =>
      InterfaceDensity.values.firstWhere(
        (e) => e.value == value,
        orElse: () => InterfaceDensity.standard,
      );

  /// Get description for this density
  String get description {
    switch (this) {
      case InterfaceDensity.compact:
        return 'Smaller spacing, more content fits on screen';
      case InterfaceDensity.standard:
        return 'Balanced spacing for most users';
      case InterfaceDensity.comfortable:
        return 'Larger spacing, easier to tap elements';
    }
  }

  /// Generate a density preview widget
  Widget toPreview({required bool selected, required VoidCallback onSelected}) {
    return InkWell(
      onTap: onSelected,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: EdgeInsets.symmetric(
          horizontal: 16 + (visualDensity.horizontal * 4),
          vertical: 12 + (visualDensity.vertical * 2),
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
          border: Border.all(color: selected ? Colors.blue : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayName,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.blue : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Enum representing different animation speed preferences
enum AnimationSpeed {
  slow('slow', 'Slow', 1.5),
  normal('normal', 'Normal', 1.0),
  fast('fast', 'Fast', 0.7),
  disabled('disabled', 'Disabled', 0.0);

  final String value;
  final String displayName;
  final double multiplier;
  const AnimationSpeed(this.value, this.displayName, this.multiplier);

  /// Create AnimationSpeed from string value
  static AnimationSpeed fromString(String value) => AnimationSpeed.values
      .firstWhere((e) => e.value == value, orElse: () => AnimationSpeed.normal);

  /// Apply this animation speed to a duration
  Duration applyTo(Duration baseDuration) {
    if (multiplier == 0.0) return Duration.zero;
    return Duration(
      milliseconds: (baseDuration.inMilliseconds * multiplier).round(),
    );
  }

  /// Check if animations are enabled
  bool get animationsEnabled => multiplier > 0.0;

  /// Get description for this animation speed
  String get description {
    switch (this) {
      case AnimationSpeed.slow:
        return 'Slower animations, easier to follow';
      case AnimationSpeed.normal:
        return 'Standard animation speed';
      case AnimationSpeed.fast:
        return 'Faster animations, snappy feel';
      case AnimationSpeed.disabled:
        return 'No animations, best performance';
    }
  }
}

/// Enum representing different layout preferences
enum LayoutPreference {
  cozy('cozy', 'Cozy', 'Smaller cards, more content'),
  balanced('balanced', 'Balanced', 'Standard layout'),
  spacious('spacious', 'Spacious', 'Larger cards, more spacing');

  final String value;
  final String displayName;
  final String description;
  const LayoutPreference(this.value, this.displayName, this.description);

  /// Create LayoutPreference from string value
  static LayoutPreference fromString(String value) =>
      LayoutPreference.values.firstWhere(
        (e) => e.value == value,
        orElse: () => LayoutPreference.balanced,
      );

  /// Get spacing multiplier for this layout preference
  double get spacingMultiplier {
    switch (this) {
      case LayoutPreference.cozy:
        return 0.8;
      case LayoutPreference.balanced:
        return 1.0;
      case LayoutPreference.spacious:
        return 1.3;
    }
  }

  /// Get card size multiplier for this layout preference
  double get cardSizeMultiplier {
    switch (this) {
      case LayoutPreference.cozy:
        return 0.9;
      case LayoutPreference.balanced:
        return 1.0;
      case LayoutPreference.spacious:
        return 1.1;
    }
  }
}

/// Enum representing different accessibility preferences
enum AccessibilityOption {
  highContrast('high_contrast', 'High Contrast'),
  largeText('large_text', 'Large Text'),
  reduceMotion('reduce_motion', 'Reduce Motion'),
  screenReader('screen_reader', 'Screen Reader Optimized');

  final String value;
  final String displayName;
  const AccessibilityOption(this.value, this.displayName);

  /// Get description for this accessibility option
  String get description {
    switch (this) {
      case AccessibilityOption.highContrast:
        return 'Increase contrast for better visibility';
      case AccessibilityOption.largeText:
        return 'Use larger text throughout the app';
      case AccessibilityOption.reduceMotion:
        return 'Minimize animations and transitions';
      case AccessibilityOption.screenReader:
        return 'Optimize layout for screen readers';
    }
  }

  /// Check if this option affects theme generation
  bool get affectsTheme {
    switch (this) {
      case AccessibilityOption.highContrast:
      case AccessibilityOption.largeText:
        return true;
      default:
        return false;
    }
  }
}
