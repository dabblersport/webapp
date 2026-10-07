import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/data/models/games/venue.dart' as games_venue;
import 'package:dabbler/data/models/venue_submission_model.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_history_screen.dart'
    show PastGame, pastGamesProvider;
import 'package:dabbler/features/explore/presentation/screens/sports_library_screen.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_screen.dart';
import 'package:dabbler/features/games/presentation/controllers/venues_controller.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/features/home/presentation/screens/main_navigation_screen.dart'
    show sportsSubTabProvider;
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/venue_submissions/presentation/screens/create_venue_submission_screen.dart';
import 'package:dabbler/features/venue_submissions/presentation/screens/my_venue_submissions_screen.dart';
import 'package:dabbler/features/venue_submissions/presentation/screens/venue_submission_detail_screen.dart';
import 'package:dabbler/features/venue_submissions/providers.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/features/venues/providers.dart' as venues_providers;
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

/// KAN-416 group R: Explore (/sports-explore), My Sports library and the
/// venue-submission screens, LTR + RTL. None has a design frame (DS defaults).
/// Writes PNGs only with `--dart-define=PLACES_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('PLACES_SHOTS_DIR');

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

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  if (_shotsDir.isEmpty) return;
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

class _Profile extends StateNotifier<ProfileState>
    implements ProfileController {
  _Profile() : super(const ProfileState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Venues extends StateNotifier<VenuesState> implements VenuesController {
  _Venues() : super(const VenuesState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final DateTime _soon = DateTime.now().add(const Duration(days: 2));

Game _game(String id, String title, String sport) => Game(
  id: id,
  title: title,
  description: '',
  sport: sport,
  venueName: 'Al Barsha Pond Park',
  scheduledDate: _soon,
  startTime: '18:00',
  endTime: '19:30',
  minPlayers: 6,
  maxPlayers: 10,
  currentPlayers: 7,
  organizerId: 'o1',
  skillLevel: 'Intermediate',
  pricePerPlayer: 30,
  status: GameStatus.upcoming,
  isPublic: true,
  allowsWaitlist: false,
  checkInEnabled: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const List<VenueWithSportModel> _venues = [
  VenueWithSportModel(
    id: 'v1',
    sportId: 's1',
    nameEn: 'Al Quoz Sports Hub',
    city: 'Dubai',
    area: 'Al Quoz',
  ),
  VenueWithSportModel(
    id: 'v2',
    sportId: 's1',
    nameEn: 'Jumeirah Football Park',
    city: 'Dubai',
  ),
];

final List<PastGame> _past = [
  PastGame(
    id: 'p1',
    title: 'Friday five-a-side',
    sport: 'Football',
    scheduledDate: DateTime(2026, 9, 12),
    startTime: '19:00',
    endTime: '20:00',
    currentPlayers: 10,
    maxPlayers: 10,
    venueName: 'Al Quoz Sports Hub',
  ),
  PastGame(
    id: 'p2',
    title: 'Padel doubles',
    sport: 'Padel',
    scheduledDate: DateTime(2026, 9, 5),
    startTime: '08:00',
    endTime: '09:30',
    currentPlayers: 4,
    maxPlayers: 4,
  ),
];

const VenueSubmissionModel _draft = VenueSubmissionModel(
  id: 'sub1',
  organiserProfileId: 'org1',
  submittedByUserId: 'u1',
  status: VenueSubmissionStatus.draft,
  nameEn: 'Marina Padel Club',
  nameAr: 'نادي مارينا للبادل',
  descriptionEn: 'Four indoor padel courts with lights.',
  city: 'Dubai',
  district: 'Dubai Marina',
  addressLine1: 'Marina Walk, Tower 3',
  phone: '+971 4 000 0000',
  isIndoor: true,
  amenities: ['Parking', 'Showers'],
);

const VenueSubmissionModel _returned = VenueSubmissionModel(
  id: 'sub2',
  organiserProfileId: 'org1',
  submittedByUserId: 'u1',
  status: VenueSubmissionStatus.returned,
  nameEn: 'Desert Cricket Ground',
  city: 'Sharjah',
  adminNote: 'Please add the exact pitch location.',
);

void Function(FlutterErrorDetails)? _origOnError;

/// The DS event card paints a sport's background PNG from
/// `assets/images/sports/<key>-main-background.png`; the DS ships none and the
/// app declares none (DS gap, reported). The Image reports the failed load via
/// FlutterError.onError and paints nothing (the DS fallback paint shows). Only
/// that one known report is ignored here; everything else still fails.
void _ignoreMissingSportArt() {
  _origOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('-main-background.png')) return;
    _origOnError?.call(details);
  };
}

void _restoreOnError() => FlutterError.onError = _origOnError;

Future<void> _pump(
  WidgetTester tester,
  Locale locale,
  Key key,
  Widget home, {
  int subTab = 1,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _ignoreMissingSportArt();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileControllerProvider.overrideWith((ref) => _Profile()),
        venuesControllerProvider.overrideWith((ref) => _Venues()),
        sportsSubTabProvider.overrideWith((ref) => subTab),
        activeAreasProvider.overrideWith((ref) async => []),
        publicGamesProvider.overrideWith(
          (ref) async => [
            _game('g1', 'Sunday five-a-side', 'Football'),
            _game('g2', 'Evening kickabout', 'Football'),
          ],
        ),
        venuesBySportWithFiltersProvider.overrideWith(
          (ref, filters) async => _venues,
        ),
        pastGamesProvider.overrideWith((ref) async => _past),
        venues_providers.favoriteVenuesForCurrentUserProvider.overrideWith(
          (ref) async => <games_venue.Venue>[],
        ),
        myVenueSubmissionsProvider.overrideWith(
          (ref) async => const Ok([_draft, _returned]),
        ),
        venueSubmissionByIdProvider.overrideWith(
          (ref, id) async => Ok(id == 'sub2' ? _returned : _draft),
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
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: home,
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  setUp(() {
    // Geolocator never answers: LocationService.init() stays pending, so no
    // permission sheet and no periodic timer are started in the test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geolocator'),
          (call) => Completer<Object?>().future,
        );
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    const Key key = Key('shot');

    testWidgets('explore venues — $dir', (tester) async {
      await _pump(tester, locale, key, const ExploreScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Sports'), findsOneWidget);
      expect(find.byType(DabblerSearchField), findsOneWidget);
      expect(find.byType(DabblerSportIcon), findsWidgets);
      expect(find.text('Al Quoz Sports Hub'), findsOneWidget);
      expect(find.byType(DabblerCardVenue), findsNWidgets(2));
      await _shoot(tester, key, 'explore-$dir');
      _restoreOnError();
    });

    testWidgets('explore games — $dir', (tester) async {
      await _pump(tester, locale, key, const ExploreScreen(), subTab: 0);
      expect(tester.takeException(), isNull);
      expect(find.text('Sunday five-a-side'), findsOneWidget);
      // Players ride in the card's progress slot, not a hand-built footer.
      expect(find.byType(DabblerCardEventPlayers), findsWidgets);
      await _shoot(tester, key, 'explore-games-$dir');
      _restoreOnError();
    });

    testWidgets('explore filter sheet — $dir', (tester) async {
      await _pump(tester, locale, key, const ExploreScreen());
      await tester.tap(
        find.bySemanticsLabel(lookupAppLocalizations(locale).listing_filters),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Apply Filters'), findsOneWidget);
      await _shoot(tester, key, 'explore-filters-$dir');
      _restoreOnError();
    });

    testWidgets('sports library — $dir', (tester) async {
      await _pump(tester, locale, key, const SportsLibraryScreen());
      expect(tester.takeException(), isNull);
      expect(
        find.text(lookupAppLocalizations(locale).sports_prefs_my_sports),
        findsOneWidget,
      );
      expect(find.text('Friday five-a-side'), findsOneWidget);
      await _shoot(tester, key, 'sports-library-$dir');
      _restoreOnError();
    });

    testWidgets('venue submissions — $dir', (tester) async {
      await _pump(tester, locale, key, const MyVenueSubmissionsScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Marina Padel Club'), findsOneWidget);
      expect(find.text('RETURNED'), findsOneWidget);
      await _shoot(tester, key, 'venue-submissions-$dir');
      _restoreOnError();
    });

    testWidgets('venue submission detail — $dir', (tester) async {
      await _pump(
        tester,
        locale,
        key,
        const VenueSubmissionDetailScreen(submissionId: 'sub1'),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Submission details'), findsOneWidget);
      expect(find.text('Submit for review'), findsOneWidget);
      await _shoot(tester, key, 'venue-submission-detail-$dir');
      _restoreOnError();
    });

    testWidgets('create venue submission — $dir', (tester) async {
      await _pump(
        tester,
        locale,
        key,
        const CreateVenueSubmissionScreen(initial: _draft),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Edit submission'), findsOneWidget);
      expect(find.byType(DabblerToggle), findsOneWidget);
      await _shoot(tester, key, 'create-venue-submission-$dir');
      _restoreOnError();
    });
  }
}
