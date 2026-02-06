import 'package:flutter/material.dart';

/// Design System Colors
///
/// ⚠️ **DEPRECATED**: This class is deprecated in favor of Material 3 ColorScheme.
///
/// **Migration Guide:**
/// - Use `Theme.of(context).colorScheme.*` instead of `AppColors.*`
/// - Use `Theme.of(context).textTheme.*` instead of hardcoded text styles
/// - See `lib/core/design_system/MATERIAL3_MIGRATION_GUIDE.md` for migration patterns
///
/// This class is maintained for backward compatibility during migration.
/// All new code should use Material 3 ColorScheme and TextTheme.
///
/// @deprecated Use Material 3 ColorScheme instead
@Deprecated(
  'Use Material 3 ColorScheme instead. See MATERIAL3_MIGRATION_GUIDE.md',
)
class AppColors {
  /// Helper method to get brightness from context
  static Brightness _getBrightness(BuildContext context) {
    return Theme.of(context).brightness;
  }

  /// Helper method to check if dark mode
  static bool _isDark(BuildContext context) {
    return _getBrightness(context) == Brightness.dark;
  }

  // ========== Theme-Aware Getters ==========
  /// Main Text - Returns dkMainTxt for dark theme, ltMainTxt for light theme
  static Color mainTxt(BuildContext context) =>
      _isDark(context) ? dkMainTxt : ltMainTxt;

  /// Body Text - Returns dkBodyTxt for dark theme, ltBodyTxt for light theme
  static Color bodyTxt(BuildContext context) =>
      _isDark(context) ? dkBodyTxt : ltBodyTxt;

  /// Captions Text - Returns dkCaptionsTxt for dark theme, ltCaptionsTxt for light theme
  static Color captionsTxt(BuildContext context) =>
      _isDark(context) ? dkCaptionsTxt : ltCaptionsTxt;

  /// Disabled Text - Returns dkDisabledTxt for dark theme, ltDisabledTxt for light theme
  static Color disabledTxt(BuildContext context) =>
      _isDark(context) ? dkDisabledTxt : ltDisabledTxt;

  /// CTA Text - Returns dkCtaTxt for dark theme, ltCtaTxt for light theme
  static Color ctaTxt(BuildContext context) =>
      _isDark(context) ? dkCtaTxt : ltCtaTxt;

  /// Section Background - Returns dkSectionBg for dark theme, ltSectionBg for light theme
  static Color sectionBg(BuildContext context) =>
      _isDark(context) ? dkSectionBg : ltSectionBg;

  /// Card - Returns dkCard for dark theme, ltCard for light theme
  static Color cardColor(BuildContext context) =>
      _isDark(context) ? dkCard : ltCard;

  /// Stroke - Returns dkStroke for dark theme, ltStroke for light theme
  static Color stroke(BuildContext context) =>
      _isDark(context) ? dkStroke : ltStroke;

  // ========== Theme-Aware Category Backgrounds ==========
  /// Main category background: deep purple (dark) or soft lavender (light)
  static Color categoryBgMain(BuildContext context) =>
      _isDark(context) ? primaryMainBtn : secondaryMainBtn;

  /// Social category background: royal blue (dark) or light sky blue (light)
  static Color categoryBgSocial(BuildContext context) =>
      _isDark(context) ? primarySocialBtn : secondarySocialBtn;

  /// Sports category background: forest green (dark) or mint green (light)
  static Color categoryBgSports(BuildContext context) =>
      _isDark(context) ? primarySportsBtn : secondarySportsBtn;

  /// Activities category background: rich magenta (dark) or light pink (light)
  static Color categoryBgActivities(BuildContext context) =>
      _isDark(context) ? primaryActivitiesBtn : secondaryActivitiesBtn;

  /// Profile category background: vivid orange (dark) or pale cream (light)
  static Color categoryBgProfile(BuildContext context) =>
      _isDark(context) ? primaryProfileBtn : secondaryProfileBtn;
  // ========== Base Colors ==========
  /// App Background - Main app background (#000000)
  static const Color appBackground = Color(0xFF000000);

  // ========== Dark Theme Base Colors ==========
  /// Dark Section Background - Deep Charcoal (#1f1f1f)
  static const Color dkSectionBg = Color(0xFF1F1F1F);

  /// Dark Card - Dark Gray (#121212)
  static const Color dkCard = Color(0xFF121212);

  /// Dark Stroke - Border/stroke color in dark theme (rgba(254, 254, 254, 0.18))
  static const Color dkStroke = Color(0x2EFEFEFE);

  // ========== Light Theme Base Colors ==========
  /// Light Section Background - Off White (#FBFBFB)
  static const Color ltSectionBg = Color(0xFFFBFBFB);

  /// Light Card - White (#FEFEFE)
  static const Color ltCard = Color(0xFFFEFEFE);

  /// Light Stroke - Border/stroke color in light theme (rgba(26, 26, 26, 0.18))
  static const Color ltStroke = Color(0x2E1A1A1A);

  // ========== Dark Theme Typography ==========
  /// Dark Main Text - Primary text (rgba(254, 254, 254, 1))
  static const Color dkMainTxt = Color(0xFFFEFEFE);

  /// Dark Body Text - Body text (rgba(254, 254, 254, 0.92))
  static const Color dkBodyTxt = Color(0xEBFEFEFE);

  /// Dark Captions Text - Captions (rgba(254, 254, 254, 0.72))
  static const Color dkCaptionsTxt = Color(0xB8FEFEFE);

  /// Dark Disabled Text - Disabled text (rgba(254, 254, 254, 0.24))
  static const Color dkDisabledTxt = Color(0x3DFEFEFE);

  /// Dark CTA Text - CTA / inverse text (#000000)
  static const Color dkCtaTxt = Color(0xFF000000);

  // ========== Light Theme Typography ==========
  /// Light Main Text - Primary text (rgba(26, 26, 26, 1))
  static const Color ltMainTxt = Color(0xFF1A1A1A);

  /// Light Body Text - Body text (rgba(26, 26, 26, 0.92))
  static const Color ltBodyTxt = Color(0xEB1A1A1A);

  /// Light Captions Text - Captions (rgba(26, 26, 26, 0.72))
  static const Color ltCaptionsTxt = Color(0xB81A1A1A);

  /// Light Disabled Text - Disabled text (rgba(26, 26, 26, 0.24))
  static const Color ltDisabledTxt = Color(0x3D1A1A1A);

  /// Light CTA Text - CTA / inverse text (#ffffff)
  static const Color ltCtaTxt = Color(0xFFFFFFFF);

  // ========== Primary Category Colors (Dark Theme) ==========
  /// Primary Main Button - Deep Purple for main screens (#4a148c)
  static const Color primaryMainBtn = Color(0xFF4A148C);

  /// Primary Social Button - Royal Blue for social screens (#023d99)
  static const Color primarySocialBtn = Color(0xFF023D99);

  /// Primary Sports Button - Forest Green for sports screens (#235826)
  static const Color primarySportsBtn = Color(0xFF235826);

  /// Primary Activities Button - Rich Magenta for activities screens (#9c2464)
  static const Color primaryActivitiesBtn = Color(0xFF9C2464);

  /// Primary Profile Button - Vivid Orange for profile screens (#ec8f1e)
  static const Color primaryProfileBtn = Color(0xFFEC8F1E);

  // ========== Secondary Category Colors (Light Theme) ==========
  /// Secondary Main Button - Soft Lavender (#e0c7ff)
  static const Color secondaryMainBtn = Color(0xFFE0C7FF);

  /// Secondary Social Button - Light Sky Blue (#d1eafa)
  static const Color secondarySocialBtn = Color(0xFFD1EAFA);

  /// Secondary Sports Button - Mint Green (#b1fbda)
  static const Color secondarySportsBtn = Color(0xFFB1FBDA);

  /// Secondary Activities Button - Light Pink (#fcdee8)
  static const Color secondaryActivitiesBtn = Color(0xFFFCDEE8);

  /// Secondary Profile Button - Pale Cream (#fcf8ea)
  static const Color secondaryProfileBtn = Color(0xFFFCF8EA);

  // ========== Common Colors (Shared Across Light & Dark) ==========
  /// Success - Green for success states (#00a63e)
  static const Color success = Color(0xFF00A63E);

  /// Danger - Red for error/danger states (#ff3b30)
  static const Color danger = Color(0xFFFF3B30);

  /// Info Link - Blue for info and links (#155dfc)
  static const Color infoLink = Color(0xFF155DFC);

  /// Warning - Orange for warning states (#ec8f1e)
  static const Color warning = Color(0xFFEC8F1E);

  // ========== Legacy/Compatibility Colors (for gradual migration) ==========
  /// @deprecated Use appBackground instead
  static const Color backgroundDark = Color(0xFF000000);

  /// @deprecated Use dkSectionBg instead
  static const Color background = Color(0xFF1F1F1F);

  /// @deprecated Use dkSectionBg instead
  static const Color bottomSectionBackground = Color(0xFF1F1F1F);

  /// @deprecated Use dkCard instead
  static const Color card = Color(0xFF121212);

  /// @deprecated Use dkCard instead
  static const Color backgroundCardDark = Color(0xFF121212);

  /// @deprecated Use primaryMainBtn instead
  static const Color primaryPurple = primaryMainBtn;

  /// @deprecated Use dkMainTxt instead
  static const Color headings = Color(0xFFFEFEFE);

  /// @deprecated Use dkMainTxt instead
  static const Color textPrimary = Color(0xFFFEFEFE);

  /// @deprecated Use dkMainTxt instead
  static const Color textOnPurple = Color(0xFFFEFEFE);

  /// @deprecated Use dkBodyTxt instead
  static const Color body = Color(0xEBFEFEFE);

  /// @deprecated Use dkBodyTxt instead
  static const Color textTertiary = Color(0xEBFEFEFE);

  /// @deprecated Use dkCaptionsTxt instead
  static const Color captions = Color(0xB8FEFEFE);

  /// @deprecated Use dkCaptionsTxt instead
  static const Color textSecondary = Color(0xB8FEFEFE);

  /// @deprecated Use dkMainTxt with opacity
  static const Color textLight70 = Color(0xB3FEFEFE);

  /// @deprecated Use dkMainTxt instead
  static const Color textDark = Color(0xFFFEFEFE);

  /// @deprecated Use danger instead
  static const Color error = danger;

  /// @deprecated Use danger with opacity
  static const Color errorBackground = Color(0x1AFF3B30);

  /// @deprecated Use danger with opacity
  static const Color errorBorder = Color(0x4DFF3B30);

  /// @deprecated Use success with opacity
  static const Color successBackground = Color(0x1A00A63E);

  /// @deprecated Use success with opacity
  static const Color successBorder = Color(0x4D00A63E);

  /// @deprecated Use primaryMainBtn with opacity
  static const Color infoBackground = Color(0x1A4A148C);

  /// @deprecated Use primaryMainBtn with opacity
  static const Color infoBorder = Color(0x4D4A148C);

  /// @deprecated Use dkMainTxt instead
  static const Color buttonForeground = Color(0xFFFEFEFE);

  /// @deprecated Use dkCard instead
  static const Color buttonDisabled = Color(0xFF121212);

  /// @deprecated Use dkCaptionsTxt instead
  static const Color buttonDisabledForeground = Color(0xB8FEFEFE);

  /// @deprecated Use ltSectionBg instead
  static const Color backgroundLight = Color(0xFFFBFBFB);

  /// @deprecated Use secondaryMainBtn instead
  static const Color primaryPurpleLight = Color(0xFFE0C7FF);

  /// @deprecated Use secondaryMainBtn instead
  static const Color backgroundLightPurple = Color(0xFFE0C7FF);

  /// @deprecated Use dkStroke instead
  static const Color borderDark = Color(0x2EFEFEFE);

  /// @deprecated Use ltStroke instead
  static const Color borderLight = Color(0x2E1A1A1A);

  /// @deprecated Use infoLink instead
  static const Color info = infoLink;

  /// @deprecated Use infoLink instead
  static const Color infoAndLinks = Color(0xFF155DFC);

  /// Success Text - Use success instead
  static const Color successText = success;

  /// Danger Text - Use danger instead
  static const Color dangerText = danger;

  /// Info and links Text - Use infoLink instead
  static const Color infoAndLinksText = infoLink;

  /// Warning Text - Use warning instead
  static const Color warningText = warning;
}
