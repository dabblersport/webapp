import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A simple circular avatar that supports both raster and SVG images
/// from either network URLs or local assets. Falls back to an icon.
class SvgNetworkOrAssetAvatar extends StatelessWidget {
  final String? imageUrlOrAsset;
  final double radius;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final Color? backgroundColor;

  const SvgNetworkOrAssetAvatar({
    super.key,
    this.imageUrlOrAsset,
    this.radius = 24,
    this.fallbackIcon = Icons.person,
    this.fallbackColor,
    this.backgroundColor,
  });

  bool get _isSvg => (imageUrlOrAsset ?? '').toLowerCase().endsWith('.svg');
  bool get _isNetwork => (imageUrlOrAsset ?? '').startsWith('http');

  @override
  Widget build(BuildContext context) {
    final bg =
        backgroundColor ??
        Theme.of(context).colorScheme.primary.withOpacity(0.1);
    final fg = fallbackColor ?? Theme.of(context).colorScheme.primary;

    Widget child;
    if (imageUrlOrAsset == null || imageUrlOrAsset!.isEmpty) {
      child = Icon(fallbackIcon, size: radius, color: fg);
    } else if (_isSvg) {
      if (_isNetwork) {
        child = SvgPicture.network(
          imageUrlOrAsset!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholderBuilder: (_) =>
              Icon(fallbackIcon, size: radius, color: fg),
        );
      } else {
        child = SvgPicture.asset(
          imageUrlOrAsset!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholderBuilder: (_) =>
              Icon(fallbackIcon, size: radius, color: fg),
        );
      }
    } else {
      if (_isNetwork) {
        child = Image.network(
          imageUrlOrAsset!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(fallbackIcon, size: radius, color: fg),
        );
      } else {
        child = Image.asset(
          imageUrlOrAsset!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(fallbackIcon, size: radius, color: fg),
        );
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(child: child),
    );
  }
}
