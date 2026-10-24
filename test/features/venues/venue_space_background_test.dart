import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/utils/sport_background_assets.dart';
import 'package:dabbler/data/models/games/venue.dart';
import 'package:dabbler/features/venues/presentation/screens/venue_detail_screen.dart';
import 'package:dabbler/features/venues/providers.dart';
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

/// KAN-637: each venue Spaces card shows the bundled sport background for that
/// space's own sport key; an unsupported key keeps the placeholder.
const String _shotsDir = String.fromEnvironment(
  'PLACES_SHOTS_DIR',
  defaultValue: '$kShotsRoot/places',
);

const _allKeys = <String>[
  'football',
  'basketball',
  'badminton',
  'cycling',
  'cricket',
  'gym',
  'tennis',
  'padel',
  'swimming',
  'running',
  'volleyball',
];

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Locale locale, {
  List<Override> overrides = const [],
  double height = 852,
}) async {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const Key key = Key('shot');
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails d) {
    debugPrint(d.toString());
    previous?.call(d);
  };
  addTearDown(() => FlutterError.onError = previous);
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
        home: screen,
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Venue _venue({List<String>? sports, int totalRatings = 128}) => Venue(
  id: 'v1',
  name: 'Elite Football Arena',
  description:
      'Eight bookable areas across football, padel and basketball, with '
      'floodlights on every outdoor space. Natural and artificial grass, '
      'changing rooms, a cafe and covered parking.',
  addressLine1: 'Sector 3, Dubai Silicon Oasis',
  city: 'Dubai',
  state: 'Dubai',
  country: 'UAE',
  postalCode: '00000',
  latitude: 25.1,
  longitude: 55.3,
  phone: '+971 4 123 4567',
  email: 'hello@elite.example',
  website: 'elite.example',
  openingTime: '06:00',
  closingTime: '23:30',
  rating: 4.6,
  totalRatings: totalRatings,
  pricePerHour: 120,
  currency: 'AED',
  supportedSports: sports ?? const ['football', 'padel', 'basketball'],
  amenities: const ['Parking', 'Wifi', 'Lighting', 'Cafe', 'Showers'],
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

List<Override> _venueOverrides(Venue venue) => [
  venueDetailProvider.overrideWith((ref, id) async => venue),
  favoriteVenueIdsForCurrentUserProvider.overrideWith(
    (ref) async => <String>{},
  ),
];

Finder _bg(String key) => find.byKey(ValueKey<String>('space-background-$key'));

Future<void> _open(
  WidgetTester tester,
  List<String> sports,
  Locale locale,
) async {
  await _pump(
    tester,
    const VenueDetailScreen(venueId: 'v1'),
    locale,
    overrides: _venueOverrides(_venue(sports: sports)),
    height: 1400,
  );
  await settleImages(tester);
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  test('the shared map covers exactly the 11 bundled files', () {
    expect(sportBackgroundAssets.keys.toSet(), _allKeys.toSet());
    for (final asset in sportBackgroundAssets.values) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
    expect(sportBackgroundAsset('yoga'), isNull);
    expect(sportBackgroundAsset(null), isNull);
  });

  for (final key in _allKeys) {
    testWidgets('space card shows the $key background', (tester) async {
      await _open(tester, [key], const Locale('en'));
      expect(_bg(key), findsOneWidget);
      final image = tester.widget<Image>(
        find.descendant(of: _bg(key), matching: find.byType(Image)),
      );
      expect((image.image as AssetImage).assetName, sportBackgroundAssets[key]);
      expect(tester.takeException(), isNull);
    }, variant: desktop);
  }

  testWidgets('unsupported key keeps the placeholder', (tester) async {
    await _open(tester, ['yoga'], const Locale('en'));
    expect(
      find.byKey(const ValueKey<String>('space-background-yoga')),
      findsNothing,
    );
    expect(find.byType(DabblerImage), findsWidgets);
    expect(find.text('Yoga'), findsWidgets);
    expect(tester.takeException(), isNull);
  }, variant: desktop);

  testWidgets('each space uses its own key, mixed with a fallback', (
    tester,
  ) async {
    await _open(tester, ['padel', 'yoga'], const Locale('en'));
    expect(_bg('padel'), findsOneWidget);
    expect(_bg('yoga'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: desktop);

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    testWidgets('multi-sport venue renders without overflow - $dir', (
      tester,
    ) async {
      await _open(tester, [
        'football',
        'padel',
        'basketball',
        'yoga',
        'tennis',
      ], locale);
      expect(tester.takeException(), isNull);
      await _shoot(tester, const Key('shot'), 'venue-spaces-backgrounds-$dir');
    }, variant: desktop);
  }
}
