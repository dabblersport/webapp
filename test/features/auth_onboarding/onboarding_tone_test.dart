import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_tone.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

double _luma(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

void main() {
  test('light tone is the design system tone', () {
    expect(onboardingHueTone(196, Brightness.light), DabblerHueTone.hue(196));
    expect(
      onboardingHueTone(233, Brightness.light, gender: true),
      DabblerHueTone.gender(233),
    );
  });

  test('dark tone has a dark card surface and a light stroke and glyph', () {
    for (final hue in <double>[12, 118, 196, 233, 350]) {
      for (final gender in <bool>[false, true]) {
        final light = onboardingHueTone(hue, Brightness.light, gender: gender);
        final dark = onboardingHueTone(hue, Brightness.dark, gender: gender);
        expect(_luma(dark.surface), lessThan(0.2), reason: 'surface $hue');
        expect(_luma(dark.surface), lessThan(_luma(light.surface)));
        expect(_luma(dark.solid), greaterThan(_luma(light.solid)));
        expect(_luma(dark.deep), greaterThan(_luma(light.deep)));
      }
    }
  });

  test('an unknown sport takes the fallback hue in both modes', () {
    expect(
      onboardingSportHueTone('curling', Brightness.dark),
      onboardingHueTone(DabblerHueTone.fallbackHue, Brightness.dark),
    );
    expect(
      onboardingSportHueTone('table_tennis', Brightness.light),
      onboardingSportHueTone('table-tennis', Brightness.light),
    );
  });
}
