import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetups_screen.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import 'meetup_screens_harness.dart';

/// Renders the Meetups screens LTR and RTL. Writes PNGs only with
/// `--dart-define=MEETUPS_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('MEETUPS_SHOTS_DIR');

class _Denied extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

Future<void> _shoot(
  WidgetTester tester,
  Widget home,
  FakeMeetupRepository repo,
  Locale locale,
  String name,
) async {
  final key = GlobalKey();
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meetupRepositoryProvider.overrideWithValue(repo),
        activeLocationProvider.overrideWith(_Denied.new),
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
  await settle(tester);
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

MeetupCard _card({
  bool cancelled = false,
  String? my,
  int going = 24,
  int capacity = 40,
}) => MeetupCard(
  id: 'm1',
  title: 'Sunrise run',
  startAt: DateTime.now().add(const Duration(hours: 20)),
  endAt: DateTime.now().add(const Duration(hours: 20, minutes: 45)),
  locationName: 'Kite Beach',
  capacity: capacity,
  isCancelled: cancelled,
  counts: MeetupCounts(going: going),
  myStatus: my,
  host: const MeetupHost(displayName: 'Dubai Running Club'),
);

void main() {
  setUpAll(loadRenderFonts);

  final details = <String, (RsvpCta, String?, int, bool)>{
    'join': (RsvpCta.rsvpGoing, null, 24, false),
    'request': (RsvpCta.request, null, 24, false),
    'going': (RsvpCta.already, 'going', 24, false),
    'interested': (RsvpCta.already, 'interested', 24, false),
    'pending': (RsvpCta.already, 'pending', 24, false),
    'full': (RsvpCta.rsvpGoing, null, 40, false),
    'closed': (RsvpCta.closed, null, 24, false),
    'cancelled': (RsvpCta.cancelled, null, 24, true),
    'started': (RsvpCta.started, null, 24, false),
    'not-allowed': (RsvpCta.notAllowed, null, 24, false),
  };
  for (final e in details.entries) {
    for (final l in <Locale>[const Locale('en'), const Locale('ar')]) {
      testWidgets('details ${e.key} ${l.languageCode}', (tester) async {
        final repo = FakeMeetupRepository()
          ..card = _card(
            cancelled: e.value.$4,
            my: e.value.$2,
            going: e.value.$3,
          )
          ..attendeeList = const [
            MeetupAttendee(
              displayName: 'Lina Haddad',
              status: RsvpStatus.going,
            ),
            MeetupAttendee(
              displayName: 'Yousef Amer',
              status: RsvpStatus.going,
            ),
            MeetupAttendee(
              displayName: 'Nadia Saleh',
              status: RsvpStatus.going,
            ),
          ]
          ..eligibility = RsvpEligibility(allowed: true, cta: e.value.$1);
        await _shoot(
          tester,
          MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
          repo,
          l,
          'meetups-details-${e.key}-${l.languageCode}',
        );
      });
    }
  }

  final listings = <String, List<MeetupListItem>>{
    'default': [
      meetupRow('a', title: 'Sunrise run'),
      meetupRow(
        'b',
        title: 'Hatta trail hike',
        going: 31,
        startsIn: const Duration(days: 3),
      ),
    ],
    'empty': const [],
    'upcoming-single': [
      meetupRow(
        'u',
        title: 'Sunrise run',
        my: 'going',
        startsIn: const Duration(hours: 20),
      ),
      meetupRow(
        'b',
        title: 'Hatta trail hike',
        going: 31,
        startsIn: const Duration(days: 3),
      ),
    ],
    'upcoming-multi': [
      meetupRow(
        'u',
        title: 'Sunrise run',
        my: 'going',
        startsIn: const Duration(hours: 20),
      ),
      meetupRow(
        'v',
        title: 'Sunset yoga flow',
        my: 'interested',
        startsIn: const Duration(days: 1, hours: 4),
      ),
      meetupRow(
        'b',
        title: 'Hatta trail hike',
        going: 31,
        startsIn: const Duration(days: 3),
      ),
    ],
  };
  for (final e in listings.entries) {
    for (final l in <Locale>[const Locale('en'), const Locale('ar')]) {
      testWidgets('listing ${e.key} ${l.languageCode}', (tester) async {
        await _shoot(
          tester,
          const MeetupsScreen(),
          FakeMeetupRepository()..list = e.value,
          l,
          'meetups-listing-${e.key}-${l.languageCode}',
        );
      });
    }
  }
}
