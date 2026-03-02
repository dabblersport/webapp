import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';
import '../tokens/avatar_tokens.dart';
import '../tokens/avatar_color_palette.dart';
import '../../../core/utils/initials_generator.dart';
import '../../../themes/material3_extensions.dart';

/// Unified avatar component following Material Design 3 specifications
///
/// Displays user avatars with consistent styling across the app.
/// Supports:
/// - Profile images or 2-character initials
/// - Category-based background colors (main, social, sports, activity, profile)
/// - Three size variants (small: 40dp, medium: 48dp, large: 64dp)
/// - Sport badge overlays
/// - Upload progress indicators
/// - Edit mode with camera icon
/// - Hero animations
/// - Interactive tap handlers
///
/// Token-driven design - no hardcoded values.
///
/// Example:
/// ```dart
/// DSAvatar.medium(
///   imageUrl: user.avatarUrl,
///   displayName: user.displayName,
///   context: AvatarContext.social,
/// )
/// ```
class DSAvatar extends StatefulWidget {
  /// Avatar size configuration
  final AvatarSize size;

  /// Image URL (network image)
  final String? imageUrl;

  /// Display name for generating initials
  final String? displayName;

  /// Pre-computed initials (overrides displayName)
  final String? initials;

  /// Category context for color theming
  final AvatarContext context;

  /// Sport emoji for badge overlay (e.g., '⚽', '🏀')
  final String? sportEmoji;

  /// Upload progress (0.0 to 1.0) - shows progress indicator
  final double? uploadProgress;

  /// Enable edit mode - shows camera icon overlay
  final bool isEditable;

  /// Callback when edit icon is tapped
  final VoidCallback? onEditTap;

  /// Callback when avatar is tapped
  final VoidCallback? onTap;

  /// Hero animation tag (null disables hero animation)
  final String? heroTag;

  /// Show error state (red border + error icon)
  final bool hasError;

  /// Show border (default: true)
  final bool hasBorder;

  /// Custom background color (overrides context color)
  final Color? backgroundColor;

  /// Custom foreground color (overrides context color)
  final Color? foregroundColor;

  const DSAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.displayName,
    this.initials,
    this.context = AvatarContext.main,
    this.sportEmoji,
    this.uploadProgress,
    this.isEditable = false,
    this.onEditTap,
    this.onTap,
    this.heroTag,
    this.hasError = false,
    this.hasBorder = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Small avatar (40dp) - Used in lists, compact views
  const DSAvatar.small({
    Key? key,
    String? imageUrl,
    String? displayName,
    String? initials,
    AvatarContext context = AvatarContext.main,
    String? sportEmoji,
    double? uploadProgress,
    bool isEditable = false,
    VoidCallback? onEditTap,
    VoidCallback? onTap,
    String? heroTag,
    bool hasError = false,
    bool hasBorder = true,
    Color? backgroundColor,
    Color? foregroundColor,
  }) : this(
         key: key,
         size: AvatarSize.small,
         imageUrl: imageUrl,
         displayName: displayName,
         initials: initials,
         context: context,
         sportEmoji: sportEmoji,
         uploadProgress: uploadProgress,
         isEditable: isEditable,
         onEditTap: onEditTap,
         onTap: onTap,
         heroTag: heroTag,
         hasError: hasError,
         hasBorder: hasBorder,
         backgroundColor: backgroundColor,
         foregroundColor: foregroundColor,
       );

  /// Medium avatar (48dp) - Used in cards, posts, default UI
  const DSAvatar.medium({
    Key? key,
    String? imageUrl,
    String? displayName,
    String? initials,
    AvatarContext context = AvatarContext.main,
    String? sportEmoji,
    double? uploadProgress,
    bool isEditable = false,
    VoidCallback? onEditTap,
    VoidCallback? onTap,
    String? heroTag,
    bool hasError = false,
    bool hasBorder = true,
    Color? backgroundColor,
    Color? foregroundColor,
  }) : this(
         key: key,
         size: AvatarSize.medium,
         imageUrl: imageUrl,
         displayName: displayName,
         initials: initials,
         context: context,
         sportEmoji: sportEmoji,
         uploadProgress: uploadProgress,
         isEditable: isEditable,
         onEditTap: onEditTap,
         onTap: onTap,
         heroTag: heroTag,
         hasError: hasError,
         hasBorder: hasBorder,
         backgroundColor: backgroundColor,
         foregroundColor: foregroundColor,
       );

  /// Large avatar (64dp) - Used in profile headers, detail views
  const DSAvatar.large({
    Key? key,
    String? imageUrl,
    String? displayName,
    String? initials,
    AvatarContext context = AvatarContext.main,
    String? sportEmoji,
    double? uploadProgress,
    bool isEditable = false,
    VoidCallback? onEditTap,
    VoidCallback? onTap,
    String? heroTag,
    bool hasError = false,
    bool hasBorder = true,
    Color? backgroundColor,
    Color? foregroundColor,
  }) : this(
         key: key,
         size: AvatarSize.large,
         imageUrl: imageUrl,
         displayName: displayName,
         initials: initials,
         context: context,
         sportEmoji: sportEmoji,
         uploadProgress: uploadProgress,
         isEditable: isEditable,
         onEditTap: onEditTap,
         onTap: onTap,
         heroTag: heroTag,
         hasError: hasError,
         hasBorder: hasBorder,
         backgroundColor: backgroundColor,
         foregroundColor: foregroundColor,
       );

  @override
  State<DSAvatar> createState() => _DSAvatarState();
}

class _DSAvatarState extends State<DSAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(
        milliseconds: AvatarTokens.interactionAnimationDuration,
      ),
      vsync: this,
    );
    _scaleAnimation =
        Tween<double>(begin: 1.0, end: AvatarTokens.tapScaleFactor).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;

    // Get category colors
    final categoryColors = AvatarColorPalette.getColors(
      context: widget.context,
      colorScheme: colorScheme,
    );

    final bgColor = widget.backgroundColor ?? categoryColors.background;
    final fgColor = widget.foregroundColor ?? categoryColors.foreground;

    // Get initials (used as fallback if RandomAvatar fails)
    final displayInitials =
        widget.initials ?? InitialsGenerator.generate(widget.displayName);

    // Seed for RandomAvatar - deterministic per user
    final avatarSeed =
        widget.displayName?.trim().toLowerCase() ?? displayInitials;

    // Build the inner content: uploaded photo > RandomAvatar > initials fallback
    Widget innerContent;
    if (hasImage) {
      innerContent = const SizedBox.shrink();
    } else {
      // RandomAvatar with initials fallback
      innerContent = Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.size.cornerRadius),
          child: _RandomAvatarWithFallback(
            seed: avatarSeed,
            size: widget.size.dimension,
            fallbackInitials: displayInitials,
            fallbackColor: fgColor,
            fallbackFontSize: widget.size.fontSize,
          ),
        ),
      );
    }

    // Avatar content
    Widget avatarContent = Container(
      width: widget.size.dimension,
      height: widget.size.dimension,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: hasImage ? null : bgColor,
        borderRadius: BorderRadius.circular(widget.size.cornerRadius),
        border: widget.hasBorder
            ? Border.all(
                color: widget.hasError
                    ? AvatarColorPalette.getErrorBorderColor(colorScheme)
                    : AvatarColorPalette.getBorderColor(colorScheme),
                width: widget.size.borderWidth,
              )
            : null,
        image: hasImage
            ? DecorationImage(
                image: NetworkImage(widget.imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: innerContent,
    );

    // Wrap in Stack for overlays
    avatarContent = Stack(
      clipBehavior: Clip.none,
      children: [
        avatarContent,
        // Sport badge overlay
        if (widget.sportEmoji != null) _buildSportBadge(colorScheme),
        // Upload progress overlay
        if (widget.uploadProgress != null) _buildUploadProgress(),
        // Edit overlay
        if (widget.isEditable) _buildEditOverlay(colorScheme),
        // Error indicator
        if (widget.hasError) _buildErrorIndicator(),
      ],
    );

    // Wrap with Hero if heroTag provided
    if (widget.heroTag != null) {
      avatarContent = Hero(
        tag: '${AvatarTokens.heroTagPrefix}-${widget.heroTag}',
        child: avatarContent,
      );
    }

    // Wrap with interactive gesture if onTap provided
    if (widget.onTap != null) {
      avatarContent = GestureDetector(
        onTapDown: (_) => _animationController.forward(),
        onTapUp: (_) {
          _animationController.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _animationController.reverse(),
        child: ScaleTransition(scale: _scaleAnimation, child: avatarContent),
      );
    }

    return avatarContent;
  }

  Widget _buildSportBadge(ColorScheme colorScheme) {
    final badgeSize = widget.size.badgeSize;

    return Positioned(
      bottom: AvatarTokens.badgeOffset,
      right: AvatarTokens.badgeOffset,
      child: Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          color: AvatarColorPalette.getSportBadgeBackground(colorScheme),
          shape: BoxShape.circle,
          border: Border.all(
            color: AvatarColorPalette.getSportBadgeBackground(colorScheme),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            widget.sportEmoji!,
            style: TextStyle(fontSize: badgeSize * 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    final progress = widget.uploadProgress!;

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: AvatarColorPalette.getEditOverlayColor(
            Theme.of(context).colorScheme,
          ),
          borderRadius: BorderRadius.circular(widget.size.cornerRadius),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: widget.size.dimension * 0.4,
                height: widget.size.dimension * 0.4,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: AvatarTokens.progressStrokeWidth,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(height: widget.size.dimension * 0.05),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.size.dimension * 0.1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditOverlay(ColorScheme colorScheme) {
    final iconSize = widget.size.iconSize * 0.6;
    final overlaySize = widget.size.iconSize;

    return Positioned(
      bottom: 0,
      right: 0,
      child: GestureDetector(
        onTap: widget.onEditTap,
        child: Container(
          width: overlaySize,
          height: overlaySize,
          decoration: BoxDecoration(
            color: widget.context == AvatarContext.main
                ? colorScheme.categoryMain
                : colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: AvatarColorPalette.getSportBadgeBackground(colorScheme),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(Icons.camera_alt, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }

  Widget _buildErrorIndicator() {
    final indicatorSize = widget.size.dimension * 0.25;

    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        width: indicatorSize,
        height: indicatorSize,
        decoration: BoxDecoration(
          color: AvatarColorPalette.getErrorBorderColor(
            Theme.of(context).colorScheme,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.error,
          color: Colors.white,
          size: indicatorSize * 0.5,
        ),
      ),
    );
  }
}

/// Internal widget that tries RandomAvatar first, falls back to initials
class _RandomAvatarWithFallback extends StatelessWidget {
  final String seed;
  final double size;
  final String fallbackInitials;
  final Color fallbackColor;
  final double fallbackFontSize;

  const _RandomAvatarWithFallback({
    required this.seed,
    required this.size,
    required this.fallbackInitials,
    required this.fallbackColor,
    required this.fallbackFontSize,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return SizedBox(
        width: 90,
        height: 90,
        child: RandomAvatar(
          seed,
          trBackground: true,
          height: size,
          width: size,
        ),
      );
    } catch (_) {
      return _buildInitialsFallback();
    }
  }

  Widget _buildInitialsFallback() {
    return Text(
      fallbackInitials,
      style: TextStyle(
        color: fallbackColor,
        fontSize: fallbackFontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}
