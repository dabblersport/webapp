import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// App-wide background matching the Pencil design.
///
/// Light mode paints the static layered background from the Pencil design
/// (Home Feed — node b68fG): a lavender base with four soft radial washes.
/// Dark mode paints its dark counterpart (Home Feed — Screenshot, node
/// N4ZNP): a `#141218` base with four deep-purple/magenta washes. The same
/// background is used on every screen so both modes stay visually
/// consistent app-wide.
class DynamicBackground extends StatelessWidget {
  const DynamicBackground({
    super.key,
    this.scrollController,
    this.tabController,
    this.scrollControllers,
    this.startColor,
  });

  /// Unused — kept for call-site compatibility with the old scroll-linked
  /// gradient. The background is now static in both brightnesses per the
  /// Pencil design.
  final ScrollController? scrollController;

  /// Unused — see [scrollController].
  final TabController? tabController;

  /// Unused — see [scrollController].
  final List<ScrollController>? scrollControllers;

  /// Unused — see [scrollController].
  final Color? startColor;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return CustomPaint(
      painter: isLight ? _AuroraPainter.light : _AuroraPainter.dark,
      size: Size.infinite,
    );
  }
}

/// One soft elliptical radial wash.
/// (center x, center y, radius w, radius h — all fractions of the screen)
class _Wash {
  const _Wash(
    this.cx,
    this.cy,
    this.w,
    this.h,
    this.color,
    this.endStop, [
    this.fadeTo,
  ]);

  final double cx;
  final double cy;
  final double w;
  final double h;
  final Color color;
  final double endStop;

  /// Hue to fade toward (at alpha 0). Defaults to [color].
  final Color? fadeTo;
}

/// Static aurora background: a base color overlaid with four soft
/// elliptical radial washes, matching the Pencil design.
class _AuroraPainter extends CustomPainter {
  const _AuroraPainter._(this._base, this._washes);

  /// Light mode — Pencil node b68fG: `#F4F0FB` base + lavender washes.
  static const light = _AuroraPainter._(Color(0xFFF4F0FB), [
    _Wash(0.85, 0.05, 0.90, 0.60, Color(0x55C18FFF), 0.80),
    _Wash(0.10, 0.35, 0.80, 0.50, Color(0x307328CD), 0.75),
    _Wash(0.90, 0.75, 0.80, 0.50, Color(0x2EA4008F), 0.70),
    _Wash(0.30, 1.00, 1.00, 0.50, Color(0x33C18FFF), 0.70),
  ]);

  /// Dark mode — Pencil node N4ZNP: `#141218` base + deep purple/magenta
  /// washes. Wash alphas fold the design's layer opacity into the color.
  static const dark = _AuroraPainter._(Color(0xFF141218), [
    _Wash(0.85, 0.05, 0.90, 0.60, Color(0x66340040), 0.80, Color(0xFFC18FFF)),
    _Wash(0.10, 0.35, 0.80, 0.50, Color(0x227328CD), 0.75),
    _Wash(0.90, 0.75, 0.80, 0.50, Color(0x17A4008F), 0.70),
    _Wash(0.30, 1.00, 1.00, 0.50, Color(0x66340040), 0.70, Color(0xFFC18FFF)),
  ]);

  final Color _base;
  final List<_Wash> _washes;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = _base);
    for (final w in _washes) {
      _paintWash(canvas, size, w);
    }
  }

  void _paintWash(Canvas canvas, Size size, _Wash wash) {
    final center = Offset(wash.cx * size.width, wash.cy * size.height);
    final rx = wash.w * size.width;
    final ry = wash.h * size.height;
    // Scale gradient space vertically about the center to get an ellipse.
    final matrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(1.0, ry / rx, 1.0, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    final shader = ui.Gradient.radial(
      center,
      rx,
      [wash.color, (wash.fadeTo ?? wash.color).withAlpha(0)],
      [0.0, wash.endStop],
      TileMode.clamp,
      matrix.storage,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate._base != _base || oldDelegate._washes != _washes;
}
