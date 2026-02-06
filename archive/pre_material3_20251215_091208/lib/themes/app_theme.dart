import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'material3_extensions.dart' as material3_extensions;
export 'material3_extensions.dart';
export '../core/theme/color_token_extensions.dart';

/// Material Design 3 theme with integrated color tokens
/// Uses native Material components with custom category colors
/// Access tokens via: Theme.of(context).colorScheme.categoryMain, .categorySocial, etc.
class AppTheme {
  /// Light Material Design 3 Theme - Main category
  static ThemeData lightTheme = _buildTheme(
    brightness: Brightness.light,
    colorScheme: _mainLightColorScheme,
  );

  /// Dark Material Design 3 Theme - Main category
  static ThemeData darkTheme = _buildTheme(
    brightness: Brightness.dark,
    colorScheme: _mainDarkColorScheme,
  );

  // Main Light Theme ColorScheme (from main-light-theme.json)
  static const ColorScheme _mainLightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF7328CE),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEADDFF),
    onPrimaryContainer: Color(0xFF25005B),
    secondary: Color(0xFFA4008F),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFD7F1),
    onSecondaryContainer: Color(0xFF3C0030),
    tertiary: Color(0xFFFF3376),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFD9E1),
    onTertiaryContainer: Color(0xFF3B0014),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFEF7FF),
    onSurface: Color(0xFF1D1B20),
    surfaceContainerHighest: Color(0xFFE6E0E9),
    surfaceContainerHigh: Color(0xFFECE6F0),
    surfaceContainer: Color(0xFFF3EDF7),
    surfaceContainerLow: Color(0xFFF7F2FA),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF49454F),
    outline: Color(0xFF7A757F),
    outlineVariant: Color(0xFFCBC4CF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF322F35),
    onInverseSurface: Color(0xFFF5EFF7),
    inversePrimary: Color(0xFFD0BCFF),
    surfaceTint: Color(0xFF7328CE),
    primaryFixed: Color(0xFFEADDFF),
    onPrimaryFixed: Color(0xFF25005B),
    primaryFixedDim: Color(0xFFD0BCFF),
    onPrimaryFixedVariant: Color(0xFF4F009A),
    secondaryFixed: Color(0xFFFFD7F1),
    onSecondaryFixed: Color(0xFF3C0030),
    secondaryFixedDim: Color(0xFFEFB1E2),
    onSecondaryFixedVariant: Color(0xFF6B005A),
    tertiaryFixed: Color(0xFFFFD9E1),
    onTertiaryFixed: Color(0xFF3B0014),
    tertiaryFixedDim: Color(0xFFFFB1C2),
    onTertiaryFixedVariant: Color(0xFF7F0031),
    surfaceDim: Color(0xFFDED8E1),
    surfaceBright: Color(0xFFFEF7FF),
  );

  // Main Dark Theme ColorScheme (from main-dark-theme.json)
  static const ColorScheme _mainDarkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFC18FFF),
    onPrimary: Color(0xFF3A0073),
    primaryContainer: Color(0xFF5500A3),
    onPrimaryContainer: Color(0xFFEADDFF),
    secondary: Color(0xFFFF86DD),
    onSecondary: Color(0xFF5A004A),
    secondaryContainer: Color(0xFF7A0065),
    onSecondaryContainer: Color(0xFFFFD7F1),
    tertiary: Color(0xFFFF8FAF),
    onTertiary: Color(0xFF640024),
    tertiaryContainer: Color(0xFF8B003C),
    onTertiaryContainer: Color(0xFFFFD9E1),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF141218),
    onSurface: Color(0xFFE6E0E9),
    surfaceContainerHighest: Color(0xFF36343B),
    surfaceContainerHigh: Color(0xFF2B2930),
    surfaceContainer: Color(0xFF211F26),
    surfaceContainerLow: Color(0xFF1D1B20),
    surfaceContainerLowest: Color(0xFF0F0D13),
    onSurfaceVariant: Color(0xFFCAC4CF),
    outline: Color(0xFF938F99),
    outlineVariant: Color(0xFF49454F),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE6E0E9),
    onInverseSurface: Color(0xFF322F35),
    inversePrimary: Color(0xFF7328CE),
    surfaceTint: Color(0xFFC18FFF),
    primaryFixed: Color(0xFFEADDFF),
    onPrimaryFixed: Color(0xFF25005B),
    primaryFixedDim: Color(0xFFD0BCFF),
    onPrimaryFixedVariant: Color(0xFF4F009A),
    secondaryFixed: Color(0xFFFFD7F1),
    onSecondaryFixed: Color(0xFF3C0030),
    secondaryFixedDim: Color(0xFFEFB1E2),
    onSecondaryFixedVariant: Color(0xFF6B005A),
    tertiaryFixed: Color(0xFFFFD9E1),
    onTertiaryFixed: Color(0xFF3B0014),
    tertiaryFixedDim: Color(0xFFFFB1C2),
    onTertiaryFixedVariant: Color(0xFF7F0031),
    surfaceDim: Color(0xFF141218),
    surfaceBright: Color(0xFF3B383E),
  );

  // Social Light Theme ColorScheme
  static const ColorScheme _socialLightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF3473D7),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD6E3FF),
    onPrimaryContainer: Color(0xFF001B3D),
    secondary: Color(0xFF65A8FF),
    onSecondary: Color(0xFF002C60),
    secondaryContainer: Color(0xFFD4E3FF),
    onSecondaryContainer: Color(0xFF001B3D),
    tertiary: Color(0xFF855BE2),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE7DEFF),
    onTertiaryContainer: Color(0xFF270057),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFDFBFF),
    onSurface: Color(0xFF1B1B1F),
    surfaceContainerHighest: Color(0xFFE6E3EC),
    surfaceContainerHigh: Color(0xFFECEAF2),
    surfaceContainer: Color(0xFFF3F3F9),
    surfaceContainerLow: Color(0xFFF7F7FC),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF44474F),
    outline: Color(0xFF74777F),
    outlineVariant: Color(0xFFC4C6D0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF303034),
    onInverseSurface: Color(0xFFF3EFF4),
    inversePrimary: Color(0xFFA6C8FF),
    surfaceTint: Color(0xFF3473D7),
    primaryFixed: Color(0xFFD6E3FF),
    onPrimaryFixed: Color(0xFF001B3D),
    primaryFixedDim: Color(0xFFA6C8FF),
    onPrimaryFixedVariant: Color(0xFF00449B),
    secondaryFixed: Color(0xFFD4E3FF),
    onSecondaryFixed: Color(0xFF001B3D),
    secondaryFixedDim: Color(0xFFA4CBFF),
    onSecondaryFixedVariant: Color(0xFF003E7C),
    tertiaryFixed: Color(0xFFE7DEFF),
    onTertiaryFixed: Color(0xFF270057),
    tertiaryFixedDim: Color(0xFFCDBEFF),
    onTertiaryFixedVariant: Color(0xFF5523A8),
    surfaceDim: Color(0xFFDFE1EB),
    surfaceBright: Color(0xFFFDFBFF),
  );

  // Social Dark Theme ColorScheme
  static const ColorScheme _socialDarkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFA6DCFF),
    onPrimary: Color(0xFF00325A),
    primaryContainer: Color(0xFF004880),
    onPrimaryContainer: Color(0xFFD6E3FF),
    secondary: Color(0xFF7EEAFF),
    onSecondary: Color(0xFF003544),
    secondaryContainer: Color(0xFF004B61),
    onSecondaryContainer: Color(0xFFC0F0FF),
    tertiary: Color(0xFFE6A2CF),
    onTertiary: Color(0xFF4A003C),
    tertiaryContainer: Color(0xFF662957),
    onTertiaryContainer: Color(0xFFFFD9EB),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF1B1B1F),
    onSurface: Color(0xFFE4E1E6),
    surfaceContainerHighest: Color(0xFF36343B),
    surfaceContainerHigh: Color(0xFF2B2A30),
    surfaceContainer: Color(0xFF212026),
    surfaceContainerLow: Color(0xFF1D1C21),
    surfaceContainerLowest: Color(0xFF0F0E13),
    onSurfaceVariant: Color(0xFFC4C6D0),
    outline: Color(0xFF8E9099),
    outlineVariant: Color(0xFF44474F),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE4E1E6),
    onInverseSurface: Color(0xFF303034),
    inversePrimary: Color(0xFF3473D7),
    surfaceTint: Color(0xFFA6DCFF),
    primaryFixed: Color(0xFFD6E3FF),
    onPrimaryFixed: Color(0xFF001B3D),
    primaryFixedDim: Color(0xFFA6C8FF),
    onPrimaryFixedVariant: Color(0xFF00449B),
    secondaryFixed: Color(0xFFD4E3FF),
    onSecondaryFixed: Color(0xFF001B3D),
    secondaryFixedDim: Color(0xFFA4CBFF),
    onSecondaryFixedVariant: Color(0xFF003E7C),
    tertiaryFixed: Color(0xFFE7DEFF),
    onTertiaryFixed: Color(0xFF270057),
    tertiaryFixedDim: Color(0xFFCDBEFF),
    onTertiaryFixedVariant: Color(0xFF5523A8),
    surfaceDim: Color(0xFF141318),
    surfaceBright: Color(0xFF3B383E),
  );

  // Sports Light Theme ColorScheme
  static const ColorScheme _sportsLightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF348638),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFB6F2B5),
    onPrimaryContainer: Color(0xFF002108),
    secondary: Color(0xFF6CBD6A),
    onSecondary: Color(0xFF003911),
    secondaryContainer: Color(0xFFB7F2AF),
    onSecondaryContainer: Color(0xFF002204),
    tertiary: Color(0xFF0050B6),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFD5E2FF),
    onTertiaryContainer: Color(0xFF001B3D),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFBFDF6),
    onSurface: Color(0xFF1A1C19),
    surfaceContainerHighest: Color(0xFFE1E4DD),
    surfaceContainerHigh: Color(0xFFE8ECE4),
    surfaceContainer: Color(0xFFEEF2EA),
    surfaceContainerLow: Color(0xFFF3F5EE),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF414941),
    outline: Color(0xFF727970),
    outlineVariant: Color(0xFFC1C9BE),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2F312E),
    onInverseSurface: Color(0xFFF0F1EC),
    inversePrimary: Color(0xFF79FFA6),
    surfaceTint: Color(0xFF348638),
    primaryFixed: Color(0xFFB6F2B5),
    onPrimaryFixed: Color(0xFF002108),
    primaryFixedDim: Color(0xFF8ED68A),
    onPrimaryFixedVariant: Color(0xFF004316),
    secondaryFixed: Color(0xFFB7F2AF),
    onSecondaryFixed: Color(0xFF002204),
    secondaryFixedDim: Color(0xFF91D98A),
    onSecondaryFixedVariant: Color(0xFF004C18),
    tertiaryFixed: Color(0xFFD5E2FF),
    onTertiaryFixed: Color(0xFF001B3D),
    tertiaryFixedDim: Color(0xFFAAC7FF),
    onTertiaryFixedVariant: Color(0xFF003C84),
    surfaceDim: Color(0xFFE1E3DD),
    surfaceBright: Color(0xFFFBFDF6),
  );

  // Sports Dark Theme ColorScheme
  static const ColorScheme _sportsDarkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF79FFC3),
    onPrimary: Color(0xFF003820),
    primaryContainer: Color(0xFF005231),
    onPrimaryContainer: Color(0xFF98FFD4),
    secondary: Color(0xFF00E6CB),
    onSecondary: Color(0xFF003732),
    secondaryContainer: Color(0xFF00504A),
    onSecondaryContainer: Color(0xFF8EFFF1),
    tertiary: Color(0xFF00D6FF),
    onTertiary: Color(0xFF00364A),
    tertiaryContainer: Color(0xFF004F6A),
    onTertiaryContainer: Color(0xFFB8EAFF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF101410),
    onSurface: Color(0xFFE1E4DD),
    surfaceContainerHighest: Color(0xFF2E332D),
    surfaceContainerHigh: Color(0xFF232822),
    surfaceContainer: Color(0xFF1B1F1A),
    surfaceContainerLow: Color(0xFF161A15),
    surfaceContainerLowest: Color(0xFF0A0E0A),
    onSurfaceVariant: Color(0xFFC1C9BE),
    outline: Color(0xFF8B9388),
    outlineVariant: Color(0xFF414941),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE1E4DD),
    onInverseSurface: Color(0xFF2F312E),
    inversePrimary: Color(0xFF348638),
    surfaceTint: Color(0xFF79FFC3),
    primaryFixed: Color(0xFFB6F2B5),
    onPrimaryFixed: Color(0xFF002108),
    primaryFixedDim: Color(0xFF8ED68A),
    onPrimaryFixedVariant: Color(0xFF004316),
    secondaryFixed: Color(0xFFB7F2AF),
    onSecondaryFixed: Color(0xFF002204),
    secondaryFixedDim: Color(0xFF91D98A),
    onSecondaryFixedVariant: Color(0xFF004C18),
    tertiaryFixed: Color(0xFFD5E2FF),
    onTertiaryFixed: Color(0xFF001B3D),
    tertiaryFixedDim: Color(0xFFAAC7FF),
    onTertiaryFixedVariant: Color(0xFF003C84),
    surfaceDim: Color(0xFF101410),
    surfaceBright: Color(0xFF373A35),
  );

  // Activities Light Theme ColorScheme
  static const ColorScheme _activitiesLightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFCF3989),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFD8E6),
    onPrimaryContainer: Color(0xFF3A0026),
    secondary: Color(0xFFEB005A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFD9E1),
    onSecondaryContainer: Color(0xFF3B0014),
    tertiary: Color(0xFFADB4FF),
    onTertiary: Color(0xFF00115A),
    tertiaryContainer: Color(0xFFE0E0FF),
    onTertiaryContainer: Color(0xFF000F52),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFFFBFF),
    onSurface: Color(0xFF1C1B1E),
    surfaceContainerHighest: Color(0xFFE5E1E6),
    surfaceContainerHigh: Color(0xFFECE7EC),
    surfaceContainer: Color(0xFFF3EFF3),
    surfaceContainerLow: Color(0xFFF9F6FA),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF4B454C),
    outline: Color(0xFF7C757D),
    outlineVariant: Color(0xFFCBC4CB),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF312F33),
    onInverseSurface: Color(0xFFF4EFF4),
    inversePrimary: Color(0xFFFFAFCE),
    surfaceTint: Color(0xFFCF3989),
    primaryFixed: Color(0xFFFFD8E6),
    onPrimaryFixed: Color(0xFF3A0026),
    primaryFixedDim: Color(0xFFFFAFCE),
    onPrimaryFixedVariant: Color(0xFF6F0047),
    secondaryFixed: Color(0xFFFFD9E1),
    onSecondaryFixed: Color(0xFF3B0014),
    secondaryFixedDim: Color(0xFFFFB1C2),
    onSecondaryFixedVariant: Color(0xFF7F0031),
    tertiaryFixed: Color(0xFFE0E0FF),
    onTertiaryFixed: Color(0xFF000F52),
    tertiaryFixedDim: Color(0xFFC1C5FF),
    onTertiaryFixedVariant: Color(0xFF353A94),
    surfaceDim: Color(0xFFE2DEE3),
    surfaceBright: Color(0xFFFFFBFF),
  );

  // Activities Dark Theme ColorScheme
  static const ColorScheme _activitiesDarkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFCDEE8),
    onPrimary: Color(0xFF5C002C),
    primaryContainer: Color(0xFF830046),
    onPrimaryContainer: Color(0xFFFFD8E6),
    secondary: Color(0xFFFED3F9),
    onSecondary: Color(0xFF5A004A),
    secondaryContainer: Color(0xFF7A0065),
    onSecondaryContainer: Color(0xFFFFD9E1),
    tertiary: Color(0xFFE3D0FF),
    onTertiary: Color(0xFF2E2A84),
    tertiaryContainer: Color(0xFF4544A3),
    onTertiaryContainer: Color(0xFFE0E0FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF1C1B1E),
    onSurface: Color(0xFFE6E1E6),
    surfaceContainerHighest: Color(0xFF323034),
    surfaceContainerHigh: Color(0xFF28262A),
    surfaceContainer: Color(0xFF1E1C20),
    surfaceContainerLow: Color(0xFF19171B),
    surfaceContainerLowest: Color(0xFF0F0D11),
    onSurfaceVariant: Color(0xFFCCC4CB),
    outline: Color(0xFF968E96),
    outlineVariant: Color(0xFF4B454C),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE6E1E6),
    onInverseSurface: Color(0xFF323034),
    inversePrimary: Color(0xFFCF3989),
    surfaceTint: Color(0xFFFCDEE8),
    primaryFixed: Color(0xFFFFD8E6),
    onPrimaryFixed: Color(0xFF3A0026),
    primaryFixedDim: Color(0xFFFFAFCE),
    onPrimaryFixedVariant: Color(0xFF6F0047),
    secondaryFixed: Color(0xFFFFD9E1),
    onSecondaryFixed: Color(0xFF3B0014),
    secondaryFixedDim: Color(0xFFFFB1C2),
    onSecondaryFixedVariant: Color(0xFF7F0031),
    tertiaryFixed: Color(0xFFE0E0FF),
    onTertiaryFixed: Color(0xFF000F52),
    tertiaryFixedDim: Color(0xFFC1C5FF),
    onTertiaryFixedVariant: Color(0xFF353A94),
    surfaceDim: Color(0xFF141316),
    surfaceBright: Color(0xFF3A383B),
  );

  // Profile Light Theme ColorScheme
  static const ColorScheme _profileLightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFF6AA4F),
    onPrimary: Color(0xFF3F2600),
    primaryContainer: Color(0xFFFFE0B3),
    onPrimaryContainer: Color(0xFF2A1700),
    secondary: Color(0xFF703900),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFDDBC),
    onSecondaryContainer: Color(0xFF251100),
    tertiary: Color(0xFFAD8A67),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFE5CC),
    onTertiaryContainer: Color(0xFF2C1707),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFFFBFF),
    onSurface: Color(0xFF1F1B16),
    surfaceContainerHighest: Color(0xFFEBE4DB),
    surfaceContainerHigh: Color(0xFFF0EAE1),
    surfaceContainer: Color(0xFFF6EFE6),
    surfaceContainerLow: Color(0xFFFCF5EC),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF4D4639),
    outline: Color(0xFF7F7667),
    outlineVariant: Color(0xFFD1C5B7),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF34302A),
    onInverseSurface: Color(0xFFF8F0E7),
    inversePrimary: Color(0xFFFFB870),
    surfaceTint: Color(0xFFF6AA4F),
    primaryFixed: Color(0xFFFFE0B3),
    onPrimaryFixed: Color(0xFF2A1700),
    primaryFixedDim: Color(0xFFFFB870),
    onPrimaryFixedVariant: Color(0xFF603E00),
    secondaryFixed: Color(0xFFFFDDBC),
    onSecondaryFixed: Color(0xFF251100),
    secondaryFixedDim: Color(0xFFFFBA80),
    onSecondaryFixedVariant: Color(0xFF552C00),
    tertiaryFixed: Color(0xFFFFE5CC),
    onTertiaryFixed: Color(0xFF2C1707),
    tertiaryFixedDim: Color(0xFFD6BA96),
    onTertiaryFixedVariant: Color(0xFF6B5139),
    surfaceDim: Color(0xFFE2DCD3),
    surfaceBright: Color(0xFFFFFBFF),
  );

  // Profile Dark Theme ColorScheme
  static const ColorScheme _profileDarkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFF4CC),
    onPrimary: Color(0xFF452B00),
    primaryContainer: Color(0xFF654200),
    onPrimaryContainer: Color(0xFFFFE0B3),
    secondary: Color(0xFFF2954B),
    onSecondary: Color(0xFF3E2000),
    secondaryContainer: Color(0xFF5A3200),
    onSecondaryContainer: Color(0xFFFFDDBC),
    tertiary: Color(0xFF9B6D4B),
    onTertiary: Color(0xFF4A3321),
    tertiaryContainer: Color(0xFF5C422C),
    onTertiaryContainer: Color(0xFFFFE5CC),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF17130E),
    onSurface: Color(0xFFEBE4DB),
    surfaceContainerHighest: Color(0xFF39352F),
    surfaceContainerHigh: Color(0xFF2E2A24),
    surfaceContainer: Color(0xFF24201A),
    surfaceContainerLow: Color(0xFF1F1B16),
    surfaceContainerLowest: Color(0xFF120F0A),
    onSurfaceVariant: Color(0xFFD1C5B7),
    outline: Color(0xFF999080),
    outlineVariant: Color(0xFF4D4639),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFEBE4DB),
    onInverseSurface: Color(0xFF34302A),
    inversePrimary: Color(0xFFF6AA4F),
    surfaceTint: Color(0xFFFFF4CC),
    primaryFixed: Color(0xFFFFE0B3),
    onPrimaryFixed: Color(0xFF2A1700),
    primaryFixedDim: Color(0xFFFFB870),
    onPrimaryFixedVariant: Color(0xFF603E00),
    secondaryFixed: Color(0xFFFFDDBC),
    onSecondaryFixed: Color(0xFF251100),
    secondaryFixedDim: Color(0xFFFFBA80),
    onSecondaryFixedVariant: Color(0xFF552C00),
    tertiaryFixed: Color(0xFFFFE5CC),
    onTertiaryFixed: Color(0xFF2C1707),
    tertiaryFixedDim: Color(0xFFD6BA96),
    onTertiaryFixedVariant: Color(0xFF6B5139),
    surfaceDim: Color(0xFF17130E),
    surfaceBright: Color(0xFF3E3933),
  );

  /// Get ColorScheme for a specific category
  static ColorScheme getColorScheme(String category, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    switch (category.toLowerCase()) {
      case 'social':
        return isDark ? _socialDarkColorScheme : _socialLightColorScheme;
      case 'sports':
        return isDark ? _sportsDarkColorScheme : _sportsLightColorScheme;
      case 'activities':
      case 'activity':
        return isDark
            ? _activitiesDarkColorScheme
            : _activitiesLightColorScheme;
      case 'profile':
        return isDark ? _profileDarkColorScheme : _profileLightColorScheme;
      case 'main':
      default:
        return isDark ? _mainDarkColorScheme : _mainLightColorScheme;
    }
  }

  /// Build Material 3 theme with comprehensive tokens
  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
  }) {
    final textTheme = GoogleFonts.robotoTextTheme(
      brightness == Brightness.light
          ? ThemeData.light().textTheme
          : ThemeData.dark().textTheme,
    );

    // Material 3 shape system - using rounded corners
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

      // AppBar Theme
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Card Theme - Material 3 uses elevation 0 and surface containers
      cardTheme: CardThemeData(
        elevation: 0,
        shape: shapeMedium,
        color: colorScheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.all(4),
      ),

      // Button Themes
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shapeMedium,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(64, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: shapeMedium,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(64, 40),
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.onSurface,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shapeMedium,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(64, 40),
          side: BorderSide(color: colorScheme.outline),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: shapeMedium,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(64, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: shapeSmall,
          minimumSize: const Size(40, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // Chip Theme - Material 3 chip styling
      chipTheme: ChipThemeData(
        shape: shapeSmall,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.secondaryContainer,
        deleteIconColor: colorScheme.onSurfaceVariant,
        disabledColor: colorScheme.onSurface.withOpacity(0.12),
        side: BorderSide.none,
        checkmarkColor: colorScheme.onPrimaryContainer,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium,
        brightness: brightness,
      ),

      // Navigation Themes
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: shapeMedium,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onSecondaryContainer);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
            );
          }
          return textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        selectedIconTheme: IconThemeData(
          color: colorScheme.onSecondaryContainer,
        ),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        indicatorColor: colorScheme.secondaryContainer,
      ),
      drawerTheme: DrawerThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
        ),
      ),

      // Segmented Button Theme
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(shapeSmall),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),

      // Search Bar Theme
      searchBarTheme: SearchBarThemeData(
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(
          colorScheme.surfaceContainerHighest,
        ),
        shape: WidgetStateProperty.all(shapeMedium),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        textStyle: WidgetStateProperty.all(textTheme.bodyLarge),
        hintStyle: WidgetStateProperty.all(
          textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        shape: shapeMedium,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        tileColor: Colors.transparent,
        selectedTileColor: colorScheme.secondaryContainer,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        shape: shapeSmall,
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurfaceVariant;
        }),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withOpacity(0.12),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),

      // Badge Theme
      badgeTheme: BadgeThemeData(
        backgroundColor: colorScheme.error,
        textColor: colorScheme.onError,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),

      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        elevation: 0,
        shape: shapeLarge,
        backgroundColor: colorScheme.surfaceContainer,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: colorScheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        backgroundColor: colorScheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        shape: shapeMedium,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        actionTextColor: colorScheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        shape: const CircleBorder(),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),

      // App-specific theme extensions
      extensions: <ThemeExtension<dynamic>>[
        material3_extensions.AppThemeExtension(
          success: const Color(0xFF00A63E),
          warning: const Color(0xFFEC8F1E),
          infoLink: const Color(0xFF155DFC),
          danger: null, // Use ColorScheme.error
        ),
      ],
    );
  }

  /// Helper to get category color based on theme brightness
  /// @deprecated Use colorScheme.getCategoryColor() instead
  @Deprecated('Use colorScheme.getCategoryColor() instead')
  static Color getCategoryColor(BuildContext context, String category) {
    return Theme.of(context).colorScheme.getCategoryColor(category);
  }

  // Compatibility methods for legacy code
  /// @deprecated Use colorScheme.surfaceContainer instead
  @Deprecated('Use colorScheme.surfaceContainer instead')
  static Color getCardBackground(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainer;

  /// @deprecated Use colorScheme.onSurface instead
  @Deprecated('Use colorScheme.onSurface instead')
  static Color getTextPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// @deprecated Use colorScheme.outline instead
  @Deprecated('Use colorScheme.outline instead')
  static Color getBorderColor(BuildContext context) =>
      Theme.of(context).colorScheme.outline;
}

/// Extension for easy theme access
///
/// This extension provides convenient access to Material 3 theme properties.
/// For app-specific theme extensions (success, warning, etc.), use the
/// AppThemeExtensionContext from material3_extensions.dart.
extension ThemeContextExtension on BuildContext {
  /// Material 3 ColorScheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Alias for compatibility
  ColorScheme get colors => colorScheme;

  /// Material 3 TextTheme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Check if dark mode is active
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // Quick access to common Material 3 colors
  Color get primaryColor => colorScheme.primary;
  Color get surfaceColor => colorScheme.surface;
  Color get backgroundColor => colorScheme.surface;
  Color get onPrimaryColor => colorScheme.onPrimary;
  Color get onSurfaceColor => colorScheme.onSurface;

  // Material 3 surface container variants
  Color get surfaceContainer => colorScheme.surfaceContainer;
  Color get surfaceContainerLow => colorScheme.surfaceContainerLow;
  Color get surfaceContainerLowest => colorScheme.surfaceContainerLowest;
  Color get surfaceContainerHigh => colorScheme.surfaceContainerHigh;
  Color get surfaceContainerHighest => colorScheme.surfaceContainerHighest;

  // Legacy compatibility helpers (deprecated but maintained for backward compatibility)
  /// @deprecated Use surfaceContainerHighest instead
  @Deprecated('Use surfaceContainerHighest instead')
  Color get violetCardBg => colorScheme.surfaceContainerHighest;

  /// @deprecated Use surfaceContainer instead
  @Deprecated('Use surfaceContainer instead')
  Color get violetWidgetBg => colorScheme.surfaceContainer;

  /// @deprecated Use surface instead
  @Deprecated('Use surface instead')
  Color get violetSurface => colorScheme.surface;

  /// Category colors using Material 3 extension
  Color categoryColor(String category) {
    return colorScheme.getCategoryColor(category);
  }
}
