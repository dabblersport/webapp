import 'package:flutter/material.dart';
import '../design_tokens/colors.dart';
import '../design_tokens/typography.dart';
import '../design_tokens/spacing.dart';

/// Core theme configuration that pulls from design tokens
class DabblerTheme {
  static ThemeData get light => _getThemeData(
    brightness: Brightness.light,
    backgroundColor: DabblerColors.backgroundLight,
    surfaceColor: DabblerColors.surfaceLight,
    textPrimaryColor: DabblerColors.textPrimaryLight,
    textSecondaryColor: DabblerColors.textSecondaryLight,
    dividerColor: DabblerColors.dividerLight,
  );

  static ThemeData get dark => _getThemeData(
    brightness: Brightness.dark,
    backgroundColor: DabblerColors.backgroundDark,
    surfaceColor: DabblerColors.surfaceDark,
    textPrimaryColor: DabblerColors.textPrimaryDark,
    textSecondaryColor: DabblerColors.textSecondaryDark,
    dividerColor: DabblerColors.dividerDark,
  );

  static ThemeData _getThemeData({
    required Brightness brightness,
    required Color backgroundColor,
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required Color dividerColor,
  }) {
    return ThemeData(
      // Color Scheme
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: DabblerColors.primary,
        secondary: DabblerColors.secondary,
        surface: surfaceColor,
        onSurface: textPrimaryColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        error: DabblerColors.error,
        onError: Colors.white,
      ),

      // Core Colors
      primaryColor: DabblerColors.primary,
      primarySwatch: DabblerColors.primary,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: surfaceColor,
      dividerColor: dividerColor,
      shadowColor: brightness == Brightness.light
          ? Colors.black.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.3),

      // Typography
      textTheme: _getTextTheme(textPrimaryColor, textSecondaryColor),
      primaryTextTheme: _getTextTheme(Colors.white, Colors.white70),

      // Component Themes
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimaryColor,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: DabblerSpacing.all8,
      ),

      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: DabblerSpacing.horizontal16,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: DabblerColors.primary,
          padding: DabblerSpacing.horizontal16,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DabblerColors.primary,
          padding: DabblerSpacing.horizontal16,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: DabblerColors.primary, width: 1),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DabblerColors.primary,
          padding: DabblerSpacing.horizontal16,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: DabblerColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: DabblerColors.error, width: 1),
        ),
        contentPadding: DabblerSpacing.all16,
      ),

      // Other Customizations
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  static TextTheme _getTextTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: DabblerTypography.headline1().copyWith(color: primaryColor),
      displayMedium: DabblerTypography.headline2().copyWith(
        color: primaryColor,
      ),
      displaySmall: DabblerTypography.headline3().copyWith(color: primaryColor),
      headlineMedium: DabblerTypography.headline4().copyWith(
        color: primaryColor,
      ),
      headlineSmall: DabblerTypography.headline5().copyWith(
        color: primaryColor,
      ),
      titleLarge: DabblerTypography.headline6().copyWith(color: primaryColor),
      bodyLarge: DabblerTypography.body1().copyWith(color: primaryColor),
      bodyMedium: DabblerTypography.body2().copyWith(color: primaryColor),
      labelLarge: DabblerTypography.button().copyWith(color: primaryColor),
      bodySmall: DabblerTypography.caption().copyWith(color: secondaryColor),
      labelSmall: DabblerTypography.overline().copyWith(color: secondaryColor),
    );
  }
}
