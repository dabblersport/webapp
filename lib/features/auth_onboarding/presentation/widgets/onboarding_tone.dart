import 'dart:math' as math;

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// KAN-681: the onboarding card tones, light and dark.
///
/// [DabblerHueTone] is light-only, so a card tinted with it stays pale on a
/// dark page. `Auth and Onboarding.dc.html` re-pins the tone lightness for
/// dark (`[data-mode="dark"]`: surface 0.29 / 0.05, edge 0.40, solid 0.80,
/// deep 0.84); this is that table.
DabblerHueTone onboardingHueTone(
  double hue,
  Brightness brightness, {
  bool gender = false,
}) {
  if (brightness == Brightness.light) {
    return gender ? DabblerHueTone.gender(hue) : DabblerHueTone.hue(hue);
  }
  return DabblerHueTone(
    surface: _oklch(0.29, gender ? 0.035 : 0.05, hue),
    edge: _oklch(0.40, gender ? 0.06 : 0.078, hue),
    solid: _oklch(0.80, 0.135, hue),
    deep: _oklch(gender ? 0.80 : 0.84, gender ? 0.135 : 0.13, hue),
  );
}

/// The tone of [sportKey] (kebab or snake case) in [brightness].
DabblerHueTone onboardingSportHueTone(String? sportKey, Brightness brightness) {
  final String? key = sportKey?.replaceAll('_', '-');
  return onboardingHueTone(
    DabblerHueTone.sportHues[key] ?? DabblerHueTone.fallbackHue,
    brightness,
  );
}

/// The paper sport card: idle is the plain card surface with the card
/// hairline, selected takes the sport's tinted surface and its solid stroke
/// (`tileStyle`, `sportTileStyle: 'paper'`).
DabblerHueTone onboardingPaperTone(
  BuildContext context,
  String? sportKey, {
  required bool selected,
}) {
  final DabblerColors colors = DabblerColors.of(context);
  final DabblerHueTone tone = onboardingSportHueTone(
    sportKey,
    colors.brightness,
  );
  return DabblerHueTone(
    surface: selected ? tone.surface : colors.surfaceCard,
    edge: colors.borderDefault,
    solid: tone.solid,
    deep: tone.deep,
    idle: colors.borderStrong,
  );
}

Color _oklch(double l, double c, double hueDegrees) {
  final double h = hueDegrees * math.pi / 180;
  final double a = c * math.cos(h);
  final double b = c * math.sin(h);
  final double l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  final double m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  final double s_ = l - 0.0894841775 * a - 1.2914855480 * b;
  final double ll = l_ * l_ * l_;
  final double mm = m_ * m_ * m_;
  final double ss = s_ * s_ * s_;
  final double r = 4.0767416621 * ll - 3.3077115913 * mm + 0.2309699292 * ss;
  final double g = -1.2684380046 * ll + 2.6097574011 * mm - 0.3413193965 * ss;
  final double bl = -0.0041960863 * ll - 0.7034186147 * mm + 1.7076147010 * ss;
  double enc(double v) {
    final double x = v.clamp(0.0, 1.0);
    return x <= 0.0031308 ? 12.92 * x : 1.055 * math.pow(x, 1 / 2.4) - 0.055;
  }

  int channel(double v) => (enc(v) * 255).round();
  return Color(_opaque | channel(r) << 16 | channel(g) << 8 | channel(bl));
}

const int _opaque = 0xFF000000;
