import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/notification_settings_repository.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/notification_settings_screen.dart';
import '../../support/render_mode.dart';

/// Writes PNGs only with `--dart-define=SETTINGS_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('SETTINGS_SHOTS_DIR');

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  Locale locale,
  Key key, {
  List<Override> overrides = const [],
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: key, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: home,
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _loadFonts() async {
  final String dsFonts = '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(
        file.readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }

  const String pkg = 'packages/dabbler_design_system';
  const List<String> glory = <String>[
    'Glory-Light.ttf', 'Glory-Regular.ttf', 'Glory-Medium.ttf',
    'Glory-SemiBold.ttf', 'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf', 'meral-sans-regular.ttf', 'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf', 'meral-sans-bold.ttf',
  ];
  for (final String prefix in <String>['$pkg/', '']) {
    await family('${prefix}Glory', glory);
    await family('${prefix}Gloock', <String>['Gloock-Regular.ttf']);
    await family('${prefix}Meral Sans', meral);
    await family('${prefix}Wingx', <String>['Wingx-Regular.otf']);
  }
  final String home = Platform.environment['HOME'] ?? '';
  final File iconsax = File(
    '$home/.pub-cache/hosted/pub.dev/iconsax_flutter-1.0.1/fonts/FlutterIconsax.ttf',
  );
  if (iconsax.existsSync()) {
    final FontLoader loader = FontLoader('packages/iconsax_flutter/FlutterIconsax')
      ..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}



class _FakeRepo implements NotificationSettingsRepository {
  _FakeRepo(this.settings);

  /// Null keeps the screen in its loading state.
  final NotificationSettings? settings;

  @override
  Future<Result<NotificationSettings, Failure>> load() {
    final s = settings;
    if (s == null) return Completer<Result<NotificationSettings, Failure>>().future;
    return Future.value(Ok(s));
  }

  @override
  Future<Result<NotificationSettings, Failure>> save(NotificationSettings s) async => Ok(s);
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  final states = <String, NotificationSettings?>{
    'loading': null,
    'default': NotificationSettings.defaults('u1'),
    'quiet-hours': const NotificationSettings(
      userId: 'u1',
      quietStartMin: 22 * 60,
      quietEndMin: 8 * 60,
      emailEnabled: true,
      mutedKinds: ['game.reminder'],
    ),
    'push-off': const NotificationSettings(userId: 'u1', pushEnabled: false),
  };

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    for (final entry in states.entries) {
      testWidgets('notification settings ${entry.key} — $dir', (tester) async {
        const Key key = Key('shot');
        await _pump(
          tester,
          const NotificationSettingsScreen(),
          locale,
          key,
          size: const Size(393, 1900),
          overrides: [
            notificationSettingsRepositoryProvider
                .overrideWithValue(_FakeRepo(entry.value)),
          ],
        );
        expect(tester.takeException(), isNull);
        final l10n = lookupAppLocalizations(locale);
        expect(find.text(l10n.settings_tile_notifications), findsWidgets);
        if (entry.value == null) {
          expect(find.byType(DabblerSpinner), findsOneWidget);
        } else {
          expect(find.byType(DabblerToggle), findsWidgets);
          expect(find.text(l10n.notif_settings_push), findsOneWidget);
        }
        if (entry.key == 'quiet-hours') {
          expect(find.text(l10n.notif_settings_quiet_start), findsOneWidget);
          expect(find.text(l10n.notif_settings_quiet_all), findsOneWidget);
        }
        await _shoot(tester, key, 'notifications-${entry.key}-$dir');
      });
    }

    testWidgets('notification settings quiet-time sheet — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(
        tester,
        const NotificationSettingsScreen(),
        locale,
        key,
        size: const Size(393, 1900),
        overrides: [
          notificationSettingsRepositoryProvider.overrideWithValue(
            _FakeRepo(const NotificationSettings(
              userId: 'u1',
              quietStartMin: 22 * 60,
              quietEndMin: 8 * 60,
            )),
          ),
        ],
      );
      await tester.tap(find.text(lookupAppLocalizations(locale).notif_settings_quiet_start));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerTimePicker), findsOneWidget);
      await _shoot(tester, key, 'notifications-time-sheet-$dir');
    });
  }
}
