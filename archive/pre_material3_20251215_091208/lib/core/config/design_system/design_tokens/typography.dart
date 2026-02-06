import 'package:flutter/material.dart';

/// Typography tokens following Ant Design hierarchy while maintaining Dabbler's brand style
class DabblerTypography {
  // Font Families
  static const String primaryFontFamily = 'Roboto';
  static const String displayFontFamily = 'Roboto';

  // Base Font Sizes (Following 8pt Grid)
  static const double _baseFontSize = 16.0;

  // Font Scale Ratios for Different Screen Sizes
  static const double _mobileScale = 1.0;
  static const double _tabletScale = 1.1;
  static const double _desktopScale = 1.2;

  // Font Weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
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
