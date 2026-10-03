import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/render_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(ThemeData theme, Widget child) => MaterialApp(
    theme: theme,
    home: Scaffold(body: Center(child: child)),
  );

  for (final Brightness brightness in Brightness.values) {
    testWidgets('app root resolves a DS token and a Dabbler* component '
        '(${brightness.name})', (tester) async {
      final ThemeData base = ThemeData(brightness: brightness);
      DabblerColors? colors;
      await tester.pumpWidget(
        host(
          DabblerDesignSystemTheme.withFonts(
            DabblerDesignSystemTheme.withTokens(base),
            locale: const Locale('en'),
          ),
          Builder(
            builder: (context) {
              colors = DabblerColors.of(context);
              return const DabblerBadge(label: 'Alpha');
            },
          ),
        ),
      );
      expect(colors, isNotNull);
      expect(colors!.brightness, brightness);
      expect(colors!.theme, DabblerDesignSystemTheme.theme);
      expect(find.byType(DabblerBadge), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the DS extension is installed and Arabic '
      'selects the Arabic sans family', (tester) async {
    final ThemeData themed = DabblerDesignSystemTheme.withTokens(
      renderThemeBase(),
    );
    expect(themed.extension<DabblerColors>(), isNotNull);
    final ThemeData ar = DabblerDesignSystemTheme.withFonts(
      themed,
      locale: const Locale('ar'),
    );
    expect(
      ar.textTheme.bodyMedium!.fontFamily,
      DabblerType.fontFamilyFor(DabblerTypeRole.sans, DabblerTypeScript.arabic),
    );
    final ThemeData en = DabblerDesignSystemTheme.withFonts(
      themed,
      locale: const Locale('en'),
    );
    expect(
      en.textTheme.bodyMedium!.fontFamily,
      DabblerType.fontFamilyFor(DabblerTypeRole.sans, DabblerTypeScript.latin),
    );
  });
}
