import 'package:dabbler/core/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-488: with no stored preference the theme follows the device appearance
/// (time-of-day theming is opt-in); any stored value is honoured unchanged.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ThemeService> load(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    final ThemeService s = ThemeService();
    await s.init();
    return s;
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearPlatformBrightnessTestValue();
  });

  test(
    'fresh install hands ThemeMode.system to MaterialApp (KAN-1021)',
    () async {
      final ThemeService s = await load(<String, Object>{});
      expect(s.autoThemeEnabled, isFalse);
      expect(s.effectiveThemeMode, ThemeMode.system);
    },
  );

  for (final ThemeMode m in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    test('explicit ${m.name} choice is honoured', () async {
      final ThemeService s = await load(<String, Object>{
        'theme_mode': m.index,
        'auto_theme_enabled': false,
      });
      expect(s.effectiveThemeMode, m);
    });
  }

  testWidgets('system mode follows a device appearance change after the '
      'first build (KAN-1021)', (WidgetTester tester) async {
    final ThemeService s = await load(<String, Object>{});
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    late Brightness seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        darkTheme: ThemeData(brightness: Brightness.dark),
        themeMode: s.effectiveThemeMode,
        home: Builder(
          builder: (BuildContext context) {
            seen = Theme.of(context).brightness;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, Brightness.light);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(seen, Brightness.dark);
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  test('stored auto_theme_enabled = true is honoured unchanged', () async {
    final ThemeService s = await load(<String, Object>{
      'auto_theme_enabled': true,
    });
    expect(s.autoThemeEnabled, isTrue);
  });

  test('stored auto_theme_enabled = false is honoured unchanged', () async {
    final ThemeService s = await load(<String, Object>{
      'auto_theme_enabled': false,
    });
    expect(s.autoThemeEnabled, isFalse);
  });

  test(
    'account row with a NULL auto_theme_enabled resolves to device-follow',
    () async {
      final ThemeService s = await load(<String, Object>{});
      await s.applyAccountRow(<String, dynamic>{
        'theme_mode': 'dark',
        'auto_theme_enabled': null,
      });
      expect(s.autoThemeEnabled, isFalse);
    },
  );

  test('account row without the auto_theme_enabled key resolves to '
      'device-follow', () async {
    final ThemeService s = await load(<String, Object>{});
    await s.applyAccountRow(<String, dynamic>{'theme_mode': 'dark'});
    expect(s.autoThemeEnabled, isFalse);
  });

  test('account row with auto_theme_enabled = true is honoured', () async {
    final ThemeService s = await load(<String, Object>{});
    await s.applyAccountRow(<String, dynamic>{'auto_theme_enabled': true});
    expect(s.autoThemeEnabled, isTrue);
  });

  test('NULL server value keeps a stored local true', () async {
    final ThemeService s = await load(<String, Object>{
      'auto_theme_enabled': true,
    });
    await s.applyAccountRow(<String, dynamic>{'auto_theme_enabled': null});
    expect(s.autoThemeEnabled, isTrue);
  });
}
