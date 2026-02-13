/// Avatar design tokens following Material Design 3 specifications
/// Defines standardized sizes, radii, and spacing for avatar components
library;

enum AvatarSize {
  /// Small avatar - 40dp
  /// Used in: lists, compact views, inline mentions
  small(
    dimension: 40.0,
    cornerRadius: 15.0,
    borderWidth: 1.0,
    fontSize: 16.0,
    badgeSize: 18.0,
    iconSize: 20.0,
  ),

  /// Medium avatar - 48dp (default)
  /// Used in: cards, posts, comments, standard UI elements
  medium(
    dimension: 48.0,
    cornerRadius: 18.0,
    borderWidth: 1.0,
    fontSize: 19.0,
    badgeSize: 22.0,
    iconSize: 24.0,
  ),

  /// Large avatar - 64dp
  /// Used in: profile headers, detail views, prominent displays
  large(
    dimension: 64.0,
    cornerRadius: 24.0,
    borderWidth: 1.5,
    fontSize: 26.0,
    badgeSize: 30.0,
    iconSize: 32.0,
  );

  const AvatarSize({
    required this.dimension,
    required this.cornerRadius,
    required this.borderWidth,
    required this.fontSize,
    required this.badgeSize,
    required this.iconSize,
  });

  /// Overall dimension (width and height) in dp
  final double dimension;

  /// Corner radius for rounded corners in dp
  final double cornerRadius;

  /// Border stroke width in dp
  final double borderWidth;

  /// Font size for initials text in sp
  final double fontSize;

  /// Badge size (sport icons, status indicators) in dp
  final double badgeSize;

  /// Icon size for edit/camera icons in dp
  final double iconSize;
}

/// Avatar layout constants
class AvatarTokens {
  AvatarTokens._();

  /// Badge position offset from bottom-right corner
  static const double badgeOffset = -2.0;

  /// Edit overlay icon opacity
  static const double editOverlayOpacity = 0.7;

  /// Edit overlay background opacity
  static const double editOverlayBackgroundOpacity = 0.5;

  /// Progress indicator stroke width
  static const double progressStrokeWidth = 3.0;

  /// Hero animation tag prefix
  static const String heroTagPrefix = 'avatar';

  /// Default border color opacity
  static const double borderOpacity = 0.2;

  /// Initials font weight
  static const double initialsFontWeight = 600.0;

  /// Animation duration for interactions (ms)
  static const int interactionAnimationDuration = 200;

  /// Scale factor for tap animation
  static const double tapScaleFactor = 0.95;
}
