import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/location/presentation/screens/saved_locations_screen.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_bar.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/presentation/widgets/location_picker_sheet.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_sheet.dart';
import 'package:dabbler/features/location/presentation/widgets/save_location_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/features/venues/presentation/widgets/place_picker_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// Renders the location surfaces (KAN-416 group S) under the design-system
/// theme in LTR and RTL and writes PNGs to the Alpha plan folder. Every data
/// source is faked; map tiles are stubbed.
const String _shotsDir = String.fromEnvironment(
  'PLACES_SHOTS_DIR',
  defaultValue: '/Users/moataz/Desktop/Dabbler-Alpha-Plan/places',
);

const Area _marina = Area(
  id: 'a1',
  name: 'Dubai Marina',
  district: 'JLT & Marina',
  city: 'Dubai',
  country: 'UAE',
  centerLat: 25.08,
  centerLng: 55.14,
);
const Area _jbr = Area(
  id: 'a2',
  name: 'JBR',
  district: 'JLT & Marina',
  city: 'Dubai',
  country: 'UAE',
  centerLat: 25.078,
  centerLng: 55.133,
);
const Area _downtown = Area(
  id: 'a3',
  name: 'Downtown',
  district: 'Downtown & DIFC',
  city: 'Dubai',
  country: 'UAE',
  centerLat: 25.197,
  centerLng: 55.274,
);

final DateTime _t = DateTime(2026, 10, 1);
final List<ProfileLocation> _saved = <ProfileLocation>[
  ProfileLocation(
    id: 's1',
    profileId: 'p',
    areaId: 'a1',
    label: ProfileLocationLabel.home,
    isPrimary: true,
    createdAt: _t,
    updatedAt: _t,
  ),
  ProfileLocation(
    id: 's2',
    profileId: 'p',
    areaId: 'a3',
    label: ProfileLocationLabel.work,
    createdAt: _t,
    updatedAt: _t,
  ),
];

class _FakeActive extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    const ActiveLocation(
      lat: 25.08,
      lng: 55.14,
      area: _marina,
      source: ActiveLocationSource.gps,
    ),
  );

  @override
  Future<void> refresh() async {}

  @override
  void setRadiusOverride(int meters) {}
}

class _FakeSaved extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => _saved;

  @override
  Future<void> updatePrimaryRadius(int meters) async {}
}

class _FakeAreaRepo implements AreaRepository {
  @override
  Future<Map<String, List<Area>>> areasByDistrict() async =>
      <String, List<Area>>{
        'JLT & Marina': <Area>[_marina, _jbr],
        'Downtown & DIFC': <Area>[_downtown],
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _loadFonts() async {
  final String dsFonts =
      '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
  }

  const String pkg = 'packages/dabbler_design_system';
  const List<String> glory = <String>[
    'Glory-Light.ttf',
    'Glory-Regular.ttf',
    'Glory-Medium.ttf',
    'Glory-SemiBold.ttf',
    'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf',
    'meral-sans-regular.ttf',
    'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf',
    'meral-sans-bold.ttf',
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
    final FontLoader loader = FontLoader(
      'packages/iconsax_flutter/FlutterIconsax',
    )..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(const Key('shot')))
            as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// A plain DS page that opens [open] after its first frame, so sheets render
/// over a page with their real route chrome.
class _SheetHost extends StatefulWidget {
  const _SheetHost({required this.open});
  final void Function(BuildContext context) open;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) =>
      const DabblerPage(body: SizedBox.expand());
}

Widget _stubTiles() => Builder(
  builder: (context) =>
      ColoredBox(color: DabblerColors.of(context).surfaceSunken),
);

Future<void> _pump(WidgetTester tester, Widget screen, Locale locale) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(_FakeActive.new),
        profileLocationNotifierProvider.overrideWith(_FakeSaved.new),
        areaRepositoryV2Provider.overrideWithValue(_FakeAreaRepo()),
        areaNameProvider.overrideWith(
          (ref, id) async => id == 'a3' ? 'Downtown' : 'Dubai Marina',
        ),
        activeAreasProvider.overrideWith(
          (ref) async => <Area>[_marina, _jbr, _downtown],
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: const Key('shot'), child: child),
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
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  final Map<String, Widget Function()> screens = <String, Widget Function()>{
    'home-location-picker': () =>
        _SheetHost(open: (c) => HomeLocationPickerSheet.show(c)),
    'location-picker': () =>
        _SheetHost(open: (c) => LocationPickerSheet.show(c)),
    'save-location': () => _SheetHost(
      open: (c) => showDabblerSheet<void>(
        context: c,
        detents: const <double>[0.85],
        builder: (_) => SaveLocationSheet(
          lat: 25.08,
          lng: 55.14,
          areaId: 'a1',
          areaName: 'Dubai Marina',
          accuracyMeters: 12,
          onUseOnce: (_, __, ___) {},
          tileLayerBuilder: _stubTiles,
        ),
      ),
    ),
    'home-location-bar': () => const DabblerPage(
      body: Column(children: <Widget>[SizedBox(height: 60), HomeLocationBar()]),
    ),
    'nearby-filter-sheet': () =>
        _SheetHost(open: (c) => NearbyFilterSheet.show(c)),
    'saved-locations': () => const SavedLocationsScreen(),
    'place-picker': () => _SheetHost(open: (c) => PlacePickerSheet.show(c)),
  };

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    for (final MapEntry<String, Widget Function()> e in screens.entries) {
      testWidgets('renders ${e.key} - $dir', (tester) async {
        await _pump(tester, e.value(), locale);
        expect(tester.takeException(), isNull);
        await _shoot(tester, '${e.key}-$dir');
      }, variant: desktop);
    }
  }

  testWidgets('home picker lists saved locations and grouped areas', (
    tester,
  ) async {
    await _pump(
      tester,
      _SheetHost(open: (c) => HomeLocationPickerSheet.show(c)),
      const Locale('en'),
    );
    expect(find.text('Your Location'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('JBR'), findsOneWidget);
    expect(find.byType(DabblerSearchField), findsOneWidget);
  });

  testWidgets('nearby filter sheet: Apply pops the selected sort', (
    tester,
  ) async {
    NearbyFilterResult? result;
    await _pump(
      tester,
      _SheetHost(open: (c) async => result = await NearbyFilterSheet.show(c)),
      const Locale('en'),
    );
    await tester.tap(find.text('Nearest first'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(result, isNotNull);
    expect(result!.radiusMeters, 10000);
  });
}
