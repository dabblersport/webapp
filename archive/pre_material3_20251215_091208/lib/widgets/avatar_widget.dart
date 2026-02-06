import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onTap;
  final bool showBorder;
  final bool showShadow;

  const AvatarWidget({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
    this.backgroundColor,
    this.textColor,
    this.onTap,
    this.showBorder = false,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            backgroundColor ?? const Color(0xFF1890FF).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size / 2),
        border: showBorder
            ? Border.all(
                color: const Color(0xFF1890FF).withValues(alpha: 0.2),
                width: 2,
              )
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size / 2),
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (context, url) =>
                    _buildInitialsFallback(context, initials),
                errorWidget: (context, url, error) =>
                    _buildInitialsFallback(context, initials),
              ),
            )
          : _buildInitialsFallback(context, initials),
    );

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }

    return avatar;
  }

  Widget _buildInitialsFallback(BuildContext context, String initials) {
    // If no initials, show user icon
    if (initials.isEmpty) {
      return Center(
        child: Icon(
          Iconsax.user_copy,
          size: size * 0.5,
          color: textColor ?? const Color(0xFF1890FF),
        ),
      );
    }

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: size * 0.4,
          color: textColor ?? const Color(0xFF1890FF),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';

    // Handle display name specifically
    final displayName = name.trim();
    if (displayName.isEmpty) return '';

    final nameParts = displayName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();

    if (nameParts.isEmpty) return '';
    if (nameParts.length == 1) {
      return nameParts[0][0].toUpperCase();
    }

    // For display names, take first letter of first two words
    return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
  }
}
