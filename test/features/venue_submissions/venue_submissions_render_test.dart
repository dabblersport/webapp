import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/venue_submission_model.dart';
import 'package:dabbler/data/repositories/venue_submission_repository.dart';
import 'package:dabbler/features/venue_submissions/presentation/screens/create_venue_submission_screen.dart';
import 'package:dabbler/features/venue_submissions/presentation/screens/my_venue_submissions_screen.dart';
import 'package:dabbler/features/venue_submissions/presentation/screens/venue_submission_detail_screen.dart';
import 'package:dabbler/features/venue_submissions/providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';

/// Writes PNGs only with `--dart-define=MISC_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('MISC_SHOTS_DIR');

/// Never called by a render; only satisfies the repository provider.
class _StubRepo implements VenueSubmissionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final Override _repoOverride = venueSubmissionRepositoryProvider
    .overrideWithValue(_StubRepo());

const VenueSubmissionModel _draft = VenueSubmissionModel(
  id: 's1',
  organiserProfileId: 'o1',
  submittedByUserId: 'u1',
  status: VenueSubmissionStatus.draft,
  nameEn: 'Marina Padel Club',
  nameAr: 'نادي مارينا للبادل',
  descriptionEn: 'Four covered courts with floodlights.',
  city: 'Dubai',
  district: 'Marina',
  addressLine1: 'Plot 12, Marina Walk',
  phone: '+971 4 555 0100',
  isIndoor: true,
  surfaceType: 'Artificial turf',
  amenities: <String>['Parking', 'Showers'],
);

const VenueSubmissionModel _returned = VenueSubmissionModel(
  id: 's2',
  organiserProfileId: 'o1',
  submittedByUserId: 'u1',
  status: VenueSubmissionStatus.returned,
  nameEn: 'Al Quoz Courts',
  city: 'Dubai',
  district: 'Al Quoz',
  adminNote: 'Please add a street address and a phone number.',
);

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  Locale locale,
  Key key,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(393, 852);
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
  for (final String prefix in <String>['$pkg/', '']) {
    await family('${prefix}Glory', <String>[
      'Glory-Light.ttf',
      'Glory-Regular.ttf',
      'Glory-Medium.ttf',
      'Glory-SemiBold.ttf',
      'Glory-Bold.ttf',
    ]);
    await family('${prefix}Gloock', <String>['Gloock-Regular.ttf']);
    await family('${prefix}Meral Sans', <String>[
      'meral-sans-light.ttf',
      'meral-sans-regular.ttf',
      'meral-sans-medium.ttf',
      'meral-sans-semibold.ttf',
      'meral-sans-bold.ttf',
    ]);
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

void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  const locales = <String, Locale>{'ltr': Locale('en'), 'rtl': Locale('ar')};

  for (final entry in locales.entries) {
    final dir = entry.key;
    final locale = entry.value;

    testWidgets('my submissions list ($dir)', (tester) async {
      final key = GlobalKey();
      await _pump(tester, const MyVenueSubmissionsScreen(), locale, key, [
        myVenueSubmissionsProvider.overrideWith(
          (ref) async => const Ok<List<VenueSubmissionModel>, Failure>(
            <VenueSubmissionModel>[_draft, _returned],
          ),
        ),
      ]);
      expect(find.text('Marina Padel Club'), findsOneWidget);
      expect(find.text('Create new submission'), findsOneWidget);
      await _shoot(tester, key, 'venue-submissions-list-$dir');
    });

    testWidgets('submission detail ($dir)', (tester) async {
      final key = GlobalKey();
      await _pump(
        tester,
        const VenueSubmissionDetailScreen(submissionId: 's2'),
        locale,
        key,
        [
          _repoOverride,
          venueSubmissionByIdProvider('s2').overrideWith(
            (ref) async => const Ok<VenueSubmissionModel, Failure>(_returned),
          ),
        ],
      );
      expect(find.text('Admin note'), findsOneWidget);
      expect(find.text('Submit for review'), findsOneWidget);
      await _shoot(tester, key, 'venue-submission-detail-$dir');
    });

    testWidgets('create submission ($dir)', (tester) async {
      final key = GlobalKey();
      await _pump(
        tester,
        const CreateVenueSubmissionScreen(initial: _draft),
        locale,
        key,
        [_repoOverride],
      );
      expect(find.text('Venue details'), findsOneWidget);
      await _shoot(tester, key, 'venue-submission-create-$dir');
    });
  }
}
