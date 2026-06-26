import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

/// Typography tokens following Ant Design hierarchy while maintaining Dabbler's brand style
class DabblerTypography {
  // Font Families
  // On iOS, return null so Flutter falls back to the system font (SF Pro
  // Display/Text, auto-selected by size). Android and other platforms keep Roboto.
  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static String? get primaryFontFamily => _isIOS ? null : 'Roboto';
  static String? get displayFontFamily => _isIOS ? null : 'Roboto';

  // Base Font Sizes (Following 8pt Grid)
  static const double _baseFontSize = 16.0;

  // Font Scale Ratios for Different Screen Sizes
  static const double _mobileScale = 1.0;
  static const double _tabletScale = 1.1;
  static const double _desktopScale = 1.2;

  // Font Weights
  // iOS renders SF Pro optically lighter than Android's Roboto at the same
  // numeric weight, so on iOS the whole ramp is shifted up one step (+100),
  // floored at w400 and capped at w700 — text never renders thin on iOS.
  static FontWeight get light => _isIOS ? FontWeight.w400 : FontWeight.w300;
  static FontWeight get regular => _isIOS ? FontWeight.w500 : FontWeight.w400;
  static FontWeight get medium => _isIOS ? FontWeight.w600 : FontWeight.w500;
  static FontWeight get semiBold => _isIOS ? FontWeight.w700 : FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // Letter Spacing
  static const double _tightLetterSpacing = -0.5;
  static const double _normalLetterSpacing = 0.0;
  static const double _wideLetterSpacing = 0.5;

  // Line Heights
  static const double _tightLineHeight = 1.2;
  static const double _normalLineHeight = 1.5;

  // Display Styles
  static TextStyle headline1({double scale = 1.0}) => TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 48 * scale,
    fontWeight: bold,
    letterSpacing: _tightLetterSpacing,
    height: _tightLineHeight,
  );

  static TextStyle headline2({double scale = 1.0}) => TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 40 * scale,
    fontWeight: bold,
    letterSpacing: _tightLetterSpacing,
    height: _tightLineHeight,
  );

  static TextStyle headline3({double scale = 1.0}) => TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 32 * scale,
    fontWeight: semiBold,
    letterSpacing: _tightLetterSpacing,
    height: _tightLineHeight,
  );

  static TextStyle headline4({double scale = 1.0}) => TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 24 * scale,
    fontWeight: semiBold,
    letterSpacing: _normalLetterSpacing,
    height: _tightLineHeight,
  );

  static TextStyle headline5({double scale = 1.0}) => TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 20 * scale,
    fontWeight: medium,
    letterSpacing: _normalLetterSpacing,
    height: _normalLineHeight,
  );

  static TextStyle headline6({double scale = 1.0}) => TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 18 * scale,
    fontWeight: medium,
    letterSpacing: _normalLetterSpacing,
    height: _normalLineHeight,
  );

  // Body Styles
  static TextStyle body1({double scale = 1.0}) => TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 16 * scale,
    fontWeight: regular,
    letterSpacing: _normalLetterSpacing,
    height: _normalLineHeight,
  );

  static TextStyle body2({double scale = 1.0}) => TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 14 * scale,
    fontWeight: regular,
    letterSpacing: _normalLetterSpacing,
    height: _normalLineHeight,
  );

  // Supporting Styles
  static TextStyle caption({double scale = 1.0}) => TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 12 * scale,
    fontWeight: regular,
    letterSpacing: _wideLetterSpacing,
    height: _normalLineHeight,
  );

  static TextStyle overline({double scale = 1.0}) => TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 10 * scale,
    fontWeight: medium,
    letterSpacing: _wideLetterSpacing,
    height: _normalLineHeight,
  );

  // Interactive Styles
  static TextStyle button({double scale = 1.0}) => TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 14 * scale,
    fontWeight: medium,
    letterSpacing: _wideLetterSpacing,
    height: _normalLineHeight,
  );

  // Helper Methods
  static TextStyle getResponsiveStyle(
    TextStyle baseStyle, {
    required BuildContext context,
  }) {
    final double width = MediaQuery.of(context).size.width;
    double scale = _mobileScale;

    if (width >= 992) {
      scale = _desktopScale;
    } else if (width >= 576) {
      scale = _tabletScale;
    }

    return baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? _baseFontSize) * scale,
    );
  }
}
