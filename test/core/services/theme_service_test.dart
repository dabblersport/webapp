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

  for (final Brightness b in Brightness.values) {
    test('fresh install follows the device appearance, ${b.name}, whatever '
        'the time of day', () async {
      TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .platformBrightnessTestValue =
          b;
      final ThemeService s = await load(<String, Object>{});
      expect(s.autoThemeEnabled, isFalse);
      expect(
        s.effectiveThemeMode,
        b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      );
    });
  }

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
