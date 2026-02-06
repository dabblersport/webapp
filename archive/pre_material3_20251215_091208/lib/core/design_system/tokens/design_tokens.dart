import 'package:flutter/material.dart';

export 'theme_extensions.dart';

/// Design Tokens extracted from tokens.json
/// Supports 10 theme modes: Main, Social, Sports, Activities, Profile (Light & Dark)
class DesignTokens {
  // Typography
  static const String fontFamilyPrimary = 'Roboto';
  static const String fontFamilyMono = 'monospace';

  // Font Sizes
  static const double fontSize2xs = 9.0;
  static const double fontSizeXs = 12.0;
  static const double fontSizeSm = 15.0;
  static const double fontSizeBase = 17.0;
  static const double fontSizeLg = 19.0;
  static const double fontSizeXl = 21.0;
  static const double fontSize2xl = 24.0;
  static const double fontSizeEx = 24.0;
  static const double fontSizeEx2 = 30.0;

  // Font Weights
  static const FontWeight fontWeightLight = FontWeight.w300;
  static const FontWeight fontWeightNormal = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemibold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;

  // Spacing (Amount)
  static const double spacing0 = 0.0;
  static const double spacing9 = 9.0;
  static const double spacingXxs = 3.0;
  static const double spacingXs = 6.0;
  static const double spacingSm = 12.0;
  static const double spacingMd = 18.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 30.0;
  static const double spacing2xl = 36.0;
  static const double spacing3xl = 42.0;
  static const double spacing4xl = 48.0;
  static const double spacing5xl = 54.0;

  // Opacity
  static const double opacity0 = 0.0;
  static const double opacity25 = 0.25;
  static const double opacity50 = 0.5;
  static const double opacity75 = 0.75;
  static const double opacity100 = 1.0;

  // Common Colors (shared across themes)
  static const Color success = Color(0xFF00A63E);
  static const Color successDark = Color(0xFF0FBF5A);
  static const Color warning = Color(0xFFEC8F1E);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color error = Color(0xFFFF3B30);
  static const Color errorDark = Color(0xFFEF4444);
  static const Color transparent = Color(0x00000000);
}

/// Theme-specific color tokens
class ThemeColorTokens {
  final Color header;
  final Color section;
  final Color button;
  final Color btnBase;
  final Color tabActive;
  final Color app;
  final Color base;
  final Color card;
  final Color stroke;
  final Color titleOnSec;
  final Color titleOnHead;
  final Color neutral;
  final Color neutralOpacity;
  final Color neutralDisabled;
  final Color onBtn;
  final Color onBtnIcon;

  const ThemeColorTokens({
    required this.header,
    required this.section,
    required this.button,
    required this.btnBase,
    required this.tabActive,
    required this.app,
    required this.base,
    required this.card,
    required this.stroke,
    required this.titleOnSec,
    required this.titleOnHead,
    required this.neutral,
    required this.neutralOpacity,
    required this.neutralDisabled,
    required this.onBtn,
    required this.onBtnIcon,
  });
}

/// Main Light Theme Colors
class MainLightColors {
  static const tokens = ThemeColorTokens(
    header: Color(0xFFE0C7FF),
    section: Color(0x2EE0C7FF), // rgba(224, 199, 255, 0.18)
    button: Color(0xFF7328CE),
    btnBase: Color(0x0F7328CE), // rgba(115, 40, 206, 0.06)
    tabActive: Color(0xFF7328CE),
    app: Color(0xFFFFFFFF),
    base: Color(0xFFFBFBFB),
    card: Color(0x99FBFBFB), // rgba(251, 251, 251, 0.6)
    stroke: Color(0x2E7328CE), // rgba(115, 40, 206, 0.18)
    titleOnSec: Color(0xFF7328CE),
    titleOnHead: Color(0xFF1A1A1A),
    neutral: Color(0xEB1A1A1A), // rgba(26, 26, 26, 0.92)
    neutralOpacity: Color(0xB81A1A1A), // rgba(26, 26, 26, 0.72)
    neutralDisabled: Color(0x3D1A1A1A), // rgba(26, 26, 26, 0.24)
    onBtn: Color(0xFFFEFEFE),
    onBtnIcon: Color(0xFFFEFEFE),
  );
}

/// Main Dark Theme Colors
class MainDarkColors {
  static const tokens = ThemeColorTokens(
    header: Color(0xFF4A148C),
    section: Color(0x524A148C), // rgba(74, 20, 140, 0.32)
    button: Color(0xFFC18FFF),
    btnBase: Color(0x0FC18FFF), // rgba(193, 143, 255, 0.06)
    tabActive: Color(0xFFC18FFF),
    app: Color(0xFF000000),
    base: Color(0xFF1F1F1F),
    card: Color(0x3DC18FFF), // rgba(193, 143, 255, 0.24)
    stroke: Color(0x2EC18FFF), // rgba(193, 143, 255, 0.18)
    titleOnSec: Color(0xFFC18FFF),
    titleOnHead: Color(0xFFFEFEFE),
    neutral: Color(0xEBFEFEFE), // rgba(254, 254, 254, 0.92)
    neutralOpacity: Color(0xB8FEFEFE), // rgba(254, 254, 254, 0.72)
    neutralDisabled: Color(0x3DFEFEFE), // rgba(254, 254, 254, 0.24)
    onBtn: Color(0xFF1A1A1A),
    onBtnIcon: Color(0xFF1A1A1A),
  );
}

/// Social Light Theme Colors
class SocialLightColors {
  static const tokens = ThemeColorTokens(
    header: Color(0xFFD1EAFA),
    section: Color(0x2ED1EAFA), // rgba(209, 234, 250, 0.18)
    button: Color(0xFF3473D7),
    btnBase: Color(0x0F3473D7), // rgba(52, 115, 215, 0.06)
    tabActive: Color(0xFF3473D7),
    app: Color(0xFFFFFFFF),
    base: Color(0xFFFBFBFB),
    card: Color(0x99FBFBFB), // rgba(251, 251, 251, 0.6)
    stroke: Color(0x2E3473D7), // rgba(52, 115, 215, 0.18)
    titleOnSec: Color(0xFF3473D7),
    titleOnHead: Color(0xFF1A1A1A),
    neutral: Color(0xEB1A1A1A), // rgba(26, 26, 26, 0.92)
    neutralOpacity: Color(0xB81A1A1A), // rgba(26, 26, 26, 0.72)
    neutralDisabled: Color(0x3D1A1A1A), // rgba(26, 26, 26, 0.24)
    onBtn: Color(0xFFFEFEFE),
    onBtnIcon: Color(0xFFFEFEFE),
  );
}

/// Social Dark Theme Colors
class SocialDarkColors {
  static const tokens = ThemeColorTokens(
    header: Color(0xFF023D99),
    section: Color(0x52023D99), // rgba(2, 61, 153, 0.32)
    button: Color(0xFFA6DCFF),
    btnBase: Color(0x0FA6DCFF), // rgba(166, 220, 255, 0.06)
    tabActive: Color(0xFFA6DCFF),
    app: Color(0xFF000000),
    base: Color(0xFF1F1F1F),
    card: Color(0x3DA6DCFF), // rgba(166, 220, 255, 0.24)
    stroke: Color(0x2EA6DCFF), // rgba(166, 220, 255, 0.18)
    titleOnSec: Color(0xFFA6DCFF),
    titleOnHead: Color(0xFFFEFEFE),
    neutral: Color(0xEBFEFEFE), // rgba(254, 254, 254, 0.92)
    neutralOpacity: Color(0xB8FEFEFE), // rgba(254, 254, 254, 0.72)
    neutralDisabled: Color(0x3DFEFEFE), // rgba(254, 254, 254, 0.24)
    onBtn: Color(0xFF1A1A1A),
    onBtnIcon: Color(0xFF1A1A1A),
  );
}

/// Sports Light Theme Colors
class SportsLightColors {
  static const tokens = ThemeColorTokens(
    header: Color(0xFFB1FBDA),
    section: Color(0x2EB1FBDA), // rgba(177, 251, 218, 0.18)
    button: Color(0xFF348638),
    btnBase: Color(0x17348638), // rgba(52, 134, 56, 0.09)
    tabActive: Color(0xFF348638),
    app: Color(0xFFFFFFFF),
    base: Color(0xFFFBFBFB),
    card: Color(0x99FBFBFB), // rgba(251, 251, 251, 0.6)
    stroke: Color(0x2E348638), // rgba(52, 134, 56, 0.18)
    titleOnSec: Color(0xFF348638),
    titleOnHead: Color(0xFF1A1A1A),
    neutral: Color(0xEB1A1A1A), // rgba(26, 26, 26, 0.92)
    neutralOpacity: Color(0xB81A1A1A), // rgba(26, 26, 26, 0.72)
    neutralDisabled: Color(0x3D1A1A1A), // rgba(26, 26, 26, 0.24)
    onBtn: Color(0xFFFEFEFE),
    onBtnIcon: Color(0xFFFEFEFE),
  );
}

/// Sports Dark Theme Colors
class SportsDarkColors {
  static const tokens = ThemeColorTokens(
    header: Color(0xFF235826),
    section: Color(0x52235826), // rgba(35, 88, 38, 0.32)
    button: Color(0xFF7FD89B),
    btnBase: Color(0x0F7FD89B), // rgba(127, 216, 155, 0.06)
    tabActive: Color(0xFF7FD89B),
    app: Color(0xFF000000),
    base: Color(0xFF1F1F1F),
    card: Color(0x3D7FD89B), // rgba(127, 216, 155, 0.24)
    stroke: Color(0x2E7FD89B), // rgba(127, 216, 155, 0.18)
    titleOnSec: Color(0xFF7FD89B),
    titleOnHead: Color(0xFFFEFEFE),
    neutral: Color(0xEBFEFEFE), // rgba(254, 254, 254, 0.92)
    neutralOpacity: Color(0xB8FEFEFE), // rgba(254, 254, 254, 0.72)
    neutralDisabled: Color(0x3DFEFEFE), // rgba(254, 254, 254, 0.24)
    onBtn: Color(0xFF1A1A1A),
    onBtnIcon: Color(0xFF1A1A1A),
  );
}

/// Activities Light Theme Colors
class ActivitiesLightColors {
  static const tokens = ThemeColorTokens(
    header: Color(0xFFFCDEE8),
    section: Color(0x2EFCDEE8), // rgba(252, 222, 232, 0.18)
    button: Color(0xFFD72078),
    btnBase: Color(0x0FD72078), // rgba(215, 32, 120, 0.06)
    tabActive: Color(0xFFD72078),
    app: Color(0xFFFFFFFF),
    base: Color(0xFFFBFBFB),
    card: Color(0x99FBFBFB), // rgba(251, 251, 251, 0.6)
    stroke: Color(0x2ED72078), // rgba(215, 32, 120, 0.18)
    titleOnSec: Color(0xFFD72078),
    titleOnHead: Color(0xFF1A1A1A),
    neutral: Color(0xEB1A1A1A), // rgba(26, 26, 26, 0.92)
    neutralOpacity: Color(0xB81A1A1A), // rgba(26, 26, 26, 0.72)
    neutralDisabled: Color(0x3D1A1A1A), // rgba(26, 26, 26, 0.24)
    onBtn: Color(0xFFFEFEFE),
    onBtnIcon: Color(0xFFFEFEFE),
  );
}

/// Activities Dark Theme Colors
class ActivitiesDarkColors {
  static const tokens = ThemeColorTokens(
    header: Color(0xFF9C2464),
    section: Color(0x529C2464), // rgba(156, 36, 100, 0.32)
    button: Color(0xFFFFA8D5),
    btnBase: Color(0x0FFFA8D5), // rgba(255, 168, 213, 0.06)
    tabActive: Color(0xFFFFA8D5),
    app: Color(0xFF000000),
    base: Color(0xFF1F1F1F),
    card: Color(0x3DFFA8D5), // rgba(255, 168, 213, 0.24)
    stroke: Color(0x2EFFA8D5), // rgba(255, 168, 213, 0.18)
    titleOnSec: Color(0xFFFFA8D5),
    titleOnHead: Color(0xFFFEFEFE),
    neutral: Color(0xEBFEFEFE), // rgba(254, 254, 254, 0.92)
    neutralOpacity: Color(0xB8FEFEFE), // rgba(254, 254, 254, 0.72)
    neutralDisabled: Color(0x3DFEFEFE), // rgba(254, 254, 254, 0.24)
    onBtn: Color(0xFF1A1A1A),
    onBtnIcon: Color(0xFF1A1A1A),
  );
}

/// Profile Light Theme Colors
class ProfileLightColors {
  static const tokens = ThemeColorTokens(
    header: Color(0xFFFCF8EA),
    section: Color(0x2EFCF8EA), // rgba(252, 248, 234, 0.18)
    button: Color(0xFFF59E0B),
    btnBase: Color(0x0FF59E0B), // rgba(245, 158, 11, 0.06)
    tabActive: Color(0xFFF59E0B),
    app: Color(0xFFFFFFFF),
    base: Color(0xFFFBFBFB),
    card: Color(0x99FBFBFB), // rgba(251, 251, 251, 0.6)
    stroke: Color(0x2EF59E0B), // rgba(245, 158, 11, 0.18)
    titleOnSec: Color(0xFFF59E0B),
    titleOnHead: Color(0xFF1A1A1A),
    neutral: Color(0xEB1A1A1A), // rgba(26, 26, 26, 0.92)
    neutralOpacity: Color(0xB81A1A1A), // rgba(26, 26, 26, 0.72)
    neutralDisabled: Color(0x3D1A1A1A), // rgba(26, 26, 26, 0.24)
    onBtn: Color(0xFFFEFEFE),
    onBtnIcon: Color(0xFFFEFEFE),
  );
}

/// Profile Dark Theme Colors
class ProfileDarkColors {
  static const tokens = ThemeColorTokens(
    header: Color(0xFFEC8F1E),
    section: Color(0x52EC8F1E), // rgba(236, 143, 30, 0.32)
    button: Color(0xFFFFCE7A),
    btnBase: Color(0x0FFFCE7A), // rgba(255, 206, 122, 0.06)
    tabActive: Color(0xFFFFCE7A),
    app: Color(0xFF000000),
    base: Color(0xFF1F1F1F),
    card: Color(0x3DFFCE7A), // rgba(255, 206, 122, 0.24)
    stroke: Color(0x2EFFCE7A), // rgba(255, 206, 122, 0.18)
    titleOnSec: Color(0xFFFFCE7A),
    titleOnHead: Color(0xFFFEFEFE),
    neutral: Color(0xEBFEFEFE), // rgba(254, 254, 254, 0.92)
    neutralOpacity: Color(0xB8FEFEFE), // rgba(254, 254, 254, 0.72)
    neutralDisabled: Color(0x3DFEFEFE), // rgba(254, 254, 254, 0.24)
    onBtn: Color(0xFF1A1A1A),
    onBtnIcon: Color(0xFF1A1A1A),
  );
}
