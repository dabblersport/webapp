import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/games_screen.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/home/presentation/widgets/section_themed.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-531: the Games listing's header block paints the section's tinted band
/// (the sport pastel green under the shell's sport theme, resolved for dark by
/// the design system), while the list below stays on the page ground.
///
/// `--dart-define=SHOT_TAG=before` writes the pre-fix frames (the band
/// assertions are skipped for those); the default `after` asserts the colours.
const String _tag = String.fromEnvironment('SHOT_TAG', defaultValue: 'after');
const String _shotsDir = String.fromEnvironment(
  'KAN531_SHOTS_DIR',
  defaultValue: 'build/test_shots/kan531',
);

const List<Sport> _sports = <Sport>[
  Sport(
    id: 's1',
    nameEn: 'Football',
    nameAr: 'كرة القدم',
    sportKey: 'football',
  ),
  Sport(id: 's2', nameEn: 'Padel', nameAr: 'بادل', sportKey: 'padel'),
  Sport(id: 's4', nameEn: 'Cricket', nameAr: 'كريكيت', sportKey: 'cricket'),
];

List<NearbyGameModel> _games() {
  final DateTime now = DateTime.now();
  return <NearbyGameModel>[
    for (var i = 0; i < 4; i++)
      NearbyGameModel(
        id: 'g$i',
        title: 'Game $i',
        sportName: 'Football',
        scheduledAt: now.add(Duration(days: i + 1)),
        status: 'upcoming',
        venueName: 'Dubai Sports City',
        distanceMeters: 3100,
        playerCount: 7,
        spotsRemaining: 3,
        isPublic: true,
      ),
  ];
}

class _ReadyLocation extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    ActiveLocation(
      lat: 25.2,
      lng: 55.3,
      area: const Area(
        id: 'a1',
        name: 'Al Barsha',
        district: 'Dubai',
        city: 'Dubai',
        country: 'AE',
        centerLat: 25.2,
        centerLng: 55.3,
      ),
      source: ActiveLocationSource.manual,
    ),
  );
}

/// The RGBA pixel at ([x], [y]) of the captured frame, as a [Color].
Color _pixel(ByteData rgba, int width, int x, int y) {
  final int o = (y * width + x) * 4;
  return Color.fromARGB(
    rgba.getUint8(o + 3),
    rgba.getUint8(o),
    rgba.getUint8(o + 1),
    rgba.getUint8(o + 2),
  );
}

void _expectNear(Color actual, Color expected, String what) {
  int d(double a, double b) => ((a - b) * 255).round().abs();
  final int worst = [
    d(actual.r, expected.r),
    d(actual.g, expected.g),
    d(actual.b, expected.b),
  ].reduce((a, b) => a > b ? a : b);
  expect(worst, lessThanOrEqualTo(2), reason: '$what: $actual vs $expected');
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    for (final Brightness brightness in Brightness.values) {
      final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
      final String mode = brightness == Brightness.dark ? 'dark' : 'light';

      testWidgets('games header band - $dir $mode', (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const Key key = Key('shot');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeLocationProvider.overrideWith(_ReadyLocation.new),
              activeChallengeSportsByProfileCountryProvider.overrideWith(
                (ref) async => _sports,
              ),
              activeSportsByProfileCountryProvider.overrideWith(
                (ref) async => _sports,
              ),
              nearbyGamesProvider.overrideWith(
                (ref, params) => Future.value(_games()),
              ),
              myPinnedGamesProvider.overrideWith(
                (ref, sportId) async => const <NearbyGameModel>[],
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => DabblerToastProvider(
                child: RepaintBoundary(key: key, child: child),
              ),
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: DabblerDesignSystemTheme.withFonts(
                DabblerDesignSystemTheme.withTokens(
                  brightness == Brightness.dark
                      ? ThemeData.dark()
                      : ThemeData.light(),
                ),
                locale: locale,
              ),
              // The shell wraps Games in the sport section theme.
              home: const SectionThemed(
                theme: DabblerTheme.sport,
                child: GamesScreen(),
              ),
            ),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await settleImages(tester);
        expect(tester.takeException(), isNull);

        late ByteData rgba;
        await tester.runAsync(() async {
          final RenderRepaintBoundary boundary =
              tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
          final ui.Image image = await boundary.toImage(pixelRatio: 1);
          rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final ByteData? png = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          Directory(_shotsDir).createSync(recursive: true);
          File(
            '$_shotsDir/$_tag-$dir-$mode.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        });

        if (_tag == 'before') return; // pre-fix frames: screenshots only

        final DabblerColors colors = DabblerColors.resolve(
          theme: DabblerTheme.sport,
          brightness: brightness,
        );
        final Color band = Color.lerp(
          colors.surfaceCard,
          colors.brandPrimary,
          DabblerListingPage.tintShare,
        )!;
        expect(band, isNot(colors.bgPrimary));

        // Edge pixels (x = 1 is outside every card and padded control) of a
        // header row and of a row well inside the list.
        final Color header = _pixel(rgba, 393, 1, 60);
        final Color list = _pixel(rgba, 393, 1, 800);
        _expectNear(header, band, 'header band $dir $mode');
        _expectNear(list, colors.bgPrimary, 'list ground $dir $mode');
        if (brightness == Brightness.light) {
          // The sport pastel green: green is the dominant channel.
          expect(header.g, greaterThan(header.r));
          expect(header.g, greaterThan(header.b));
        }
      }, variant: desktop);
    }
  }
}
