import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';
import '../typography/app_typography.dart';

/// Theme Mode enum for all 10 supported themes
enum AppThemeMode {
  mainLight,
  mainDark,
  socialLight,
  socialDark,
  sportsLight,
  sportsDark,
  activitiesLight,
  activitiesDark,
  profileLight,
  profileDark,
}

/// Extension to get theme mode details
extension AppThemeModeExtension on AppThemeMode {
  bool get isLight {
    return this == AppThemeMode.mainLight ||
        this == AppThemeMode.socialLight ||
        this == AppThemeMode.sportsLight ||
        this == AppThemeMode.activitiesLight ||
        this == AppThemeMode.profileLight;
  }

  bool get isDark => !isLight;

  String get category {
    switch (this) {
      case AppThemeMode.mainLight:
      case AppThemeMode.mainDark:
        return 'main';
      case AppThemeMode.socialLight:
      case AppThemeMode.socialDark:
        return 'social';
      case AppThemeMode.sportsLight:
      case AppThemeMode.sportsDark:
        return 'sports';
      case AppThemeMode.activitiesLight:
      case AppThemeMode.activitiesDark:
        return 'activities';
      case AppThemeMode.profileLight:
      case AppThemeMode.profileDark:
        return 'profile';
    }
  }

  ThemeColorTokens get colorTokens {
    switch (this) {
      case AppThemeMode.mainLight:
        return MainLightColors.tokens;
      case AppThemeMode.mainDark:
        return MainDarkColors.tokens;
      case AppThemeMode.socialLight:
        return SocialLightColors.tokens;
      case AppThemeMode.socialDark:
        return SocialDarkColors.tokens;
      case AppThemeMode.sportsLight:
        return SportsLightColors.tokens;
      case AppThemeMode.sportsDark:
        return SportsDarkColors.tokens;
      case AppThemeMode.activitiesLight:
        return ActivitiesLightColors.tokens;
      case AppThemeMode.activitiesDark:
        return ActivitiesDarkColors.tokens;
      case AppThemeMode.profileLight:
        return ProfileLightColors.tokens;
      case AppThemeMode.profileDark:
        return ProfileDarkColors.tokens;
    }
  }
}

/// Token-based theme builder
class TokenBasedTheme {
  /// Build Material 3 theme from design tokens
  static ThemeData build(AppThemeMode themeMode) {
    final tokens = themeMode.colorTokens;
    final isLight = themeMode.isLight;
    final brightness = isLight ? Brightness.light : Brightness.dark;

    // Create ColorScheme from tokens
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.button,
      onPrimary: tokens.onBtn,
      primaryContainer: tokens.btnBase,
      onPrimaryContainer: tokens.titleOnSec,
      secondary: tokens.tabActive,
      onSecondary: tokens.onBtn,
      secondaryContainer: tokens.section,
      onSecondaryContainer: tokens.titleOnSec,
      tertiary: tokens.header,
      onTertiary: tokens.titleOnHead,
      tertiaryContainer: tokens.section,
      onTertiaryContainer: tokens.titleOnSec,
      error: isLight ? DesignTokens.error : DesignTokens.errorDark,
      onError: tokens.onBtn,
      surface: tokens.base,
      onSurface: tokens.neutral,
      surfaceContainerLowest: tokens.app,
      surfaceContainerLow: tokens.card,
      surfaceContainer: tokens.card,
      surfaceContainerHigh: tokens.section,
      surfaceContainerHighest: tokens.header,
      onSurfaceVariant: tokens.neutralOpacity,
      outline: tokens.stroke,
      outlineVariant: tokens.stroke,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isLight ? tokens.base : tokens.app,
      onInverseSurface: isLight ? tokens.neutral : tokens.titleOnHead,
      inversePrimary: tokens.titleOnSec,
    );

    // Text theme using Roboto from tokens
    final baseTextTheme = isLight
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    final textTheme = GoogleFonts.robotoTextTheme(baseTextTheme).copyWith(
      // Display styles - from Figma AppTypography
      displayLarge: AppTypography.displayLarge.copyWith(color: tokens.neutral),
      displayMedium: AppTypography.displayMedium.copyWith(
        color: tokens.neutral,
      ),
      displaySmall: AppTypography.displaySmall.copyWith(color: tokens.neutral),

      // Headline styles - from Figma AppTypography
      headlineLarge: AppTypography.headlineLarge.copyWith(
        color: tokens.neutral,
      ),
      headlineMedium: AppTypography.headlineMedium.copyWith(
        color: tokens.neutral,
      ),
      headlineSmall: AppTypography.headlineSmall.copyWith(
        color: tokens.neutral,
      ),

      // Title styles - from Figma AppTypography
      titleLarge: AppTypography.titleLarge.copyWith(color: tokens.neutral),
      titleMedium: AppTypography.titleMedium.copyWith(color: tokens.neutral),
      titleSmall: AppTypography.titleSmall.copyWith(color: tokens.neutral),

      // Body styles - from Figma AppTypography
      bodyLarge: AppTypography.bodyLarge.copyWith(color: tokens.neutral),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: tokens.neutral),
      bodySmall: AppTypography.bodySmall.copyWith(color: tokens.neutral),

      // Label styles - from Figma AppTypography
      labelLarge: AppTypography.labelLarge.copyWith(color: tokens.neutral),
      labelMedium: AppTypography.labelMedium.copyWith(color: tokens.neutral),
      labelSmall: AppTypography.labelSmall.copyWith(color: tokens.neutral),
    );

    // Shape system using tokens
    const shapeSmall = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    );
    const shapeMedium = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    const shapeLarge = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,

      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: tokens.neutral,
        titleTextStyle: textTheme.titleLarge,
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: 0,
        shape: shapeMedium,
        color: tokens.card,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.all(DesignTokens.spacingXs),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.button,
          foregroundColor: tokens.onBtn,
          shape: shapeMedium,
          padding: EdgeInsets.symmetric(
            horizontal: DesignTokens.spacingLg,
            vertical: DesignTokens.spacingSm,
          ),
          minimumSize: Size(64, DesignTokens.spacingLg + 16),
          textStyle: GoogleFonts.roboto(
            fontSize: DesignTokens.fontSizeSm,
            fontWeight: DesignTokens.fontWeightMedium,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: tokens.btnBase,
          foregroundColor: tokens.titleOnSec,
          shape: shapeMedium,
          padding: EdgeInsets.symmetric(
            horizontal: DesignTokens.spacingLg,
            vertical: DesignTokens.spacingSm,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.titleOnSec,
          side: BorderSide(color: tokens.stroke),
          shape: shapeMedium,
          padding: EdgeInsets.symmetric(
            horizontal: DesignTokens.spacingLg,
            vertical: DesignTokens.spacingSm,
          ),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.button, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingSm,
          vertical: DesignTokens.spacingSm,
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        shape: shapeSmall,
        backgroundColor: tokens.btnBase,
        selectedColor: tokens.button,
        labelStyle: GoogleFonts.roboto(
          fontSize: DesignTokens.fontSizeXs,
          fontWeight: DesignTokens.fontWeightMedium,
          color: tokens.neutralOpacity,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingSm,
          vertical: DesignTokens.spacingXs,
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: tokens.stroke,
        thickness: 1,
        space: 1,
      ),

      // List Tile
      listTileTheme: ListTileThemeData(
        shape: shapeMedium,
        contentPadding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingSm,
          vertical: DesignTokens.spacingXs,
        ),
        iconColor: tokens.neutralOpacity,
        textColor: tokens.neutral,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        elevation: 0,
        shape: shapeLarge,
        backgroundColor: tokens.card,
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        backgroundColor: tokens.card,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        shape: shapeMedium,
        backgroundColor: tokens.card,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Get all themes as a map
  static Map<AppThemeMode, ThemeData> getAllThemes() {
    return {for (var mode in AppThemeMode.values) mode: build(mode)};
  }
}
