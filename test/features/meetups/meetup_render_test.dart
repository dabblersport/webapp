import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/home/presentation/widgets/section_themed.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_filters.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_follow.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/active_location.dart';
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

import '../../support/geometry_dump.dart';
import '../../support/render_mode.dart';
import 'meetup_screens_harness.dart';

/// Renders the Meetups screens LTR and RTL. Writes PNGs only with
/// `--dart-define=MEETUPS_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('MEETUPS_SHOTS_DIR');

class _Ready extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    const ActiveLocation(
      lat: 25.2,
      lng: 55.27,
      source: ActiveLocationSource.saved,
      area: Area(
        id: 'a1',
        name: 'Dubai Marina',
        district: 'Marina',
        city: 'Dubai',
        country: 'AE',
        centerLat: 25.2,
        centerLng: 55.27,
      ),
    ),
  );
}

Future<void> _shoot(
  WidgetTester tester,
  Widget home,
  FakeMeetupRepository repo,
  Locale locale,
  String name, {
  Future<void> Function()? before,
  List<Override> overrides = const <Override>[],
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meetupRepositoryProvider.overrideWithValue(repo),
        activeLocationProvider.overrideWith(_Ready.new),
        myProfileIdProvider.overrideWith((ref) async => 'me'),
        isFollowingProvider.overrideWith((ref, p) async => false),
        meetupFollowActionProvider.overrideWithValue(
          ({
            required String myProfileId,
            required String targetProfileId,
            required bool currentlyFollowing,
          }) async {},
        ),
        ...overrides,
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
  await before?.call();
  dumpGeometry(tester, name);
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
  String title = 'Sunrise run',
  bool cancelled = false,
  String? my,
  int going = 24,
  int capacity = 40,
}) => MeetupCard(
  id: 'm1',
  title: title,
  startAt: DateTime.now().add(const Duration(hours: 20)),
  endAt: DateTime.now().add(const Duration(hours: 20, minutes: 45)),
  locationName: 'Kite Beach',
  capacity: capacity,
  isCancelled: cancelled,
  counts: MeetupCounts(going: going),
  myStatus: my,
  sportNameEn: 'Running',
  sportNameAr: 'جري',
  minSkill: 1,
  maxSkill: 2,
  host: const MeetupHost(
    actorProfileId: 'host1',
    displayName: 'Dubai Running Club',
  ),
  attendees: const <MeetupAvatar>[
    MeetupAvatar(displayName: 'Lina Haddad'),
    MeetupAvatar(displayName: 'Yousef Amer'),
    MeetupAvatar(displayName: 'Nadia Saleh'),
    MeetupAvatar(displayName: 'Rami Kassab'),
    MeetupAvatar(displayName: 'Hessa Ali'),
    MeetupAvatar(displayName: 'Omar Nabil'),
    MeetupAvatar(displayName: 'Dana Youssef'),
  ],
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
          ..list = [meetupRow('m1', vibeKey: 'supportive')]
          ..nearbyList = const [
            NearbyMeetup(id: 'm1', title: 't', distanceM: 3000),
          ]
          ..card = _card(
            title: l.languageCode == 'ar' ? 'جري الشروق' : 'Sunrise run',
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

  const faces = <MeetupAvatar>[
    MeetupAvatar(displayName: 'Ahmed Farouk'),
    MeetupAvatar(displayName: 'Lina Haddad'),
    MeetupAvatar(displayName: 'Yousef Amer'),
    MeetupAvatar(displayName: 'Nadia Saleh'),
  ];
  final nearby = const [
    NearbyMeetup(id: 'a', title: 't', distanceM: 3000),
    NearbyMeetup(id: 'b', title: 't', distanceM: 4200),
    NearbyMeetup(id: 'u', title: 't', distanceM: 4600),
    NearbyMeetup(id: 'v', title: 't', distanceM: 5200),
  ];
  List<MeetupListItem> rows(String lang, {int upcoming = 1}) {
    String t(String en, String ar) => lang == 'ar' ? ar : en;
    return [
      if (upcoming >= 1)
        meetupRow(
          'u',
          title: t('Sunrise run', 'جري الشروق'),
          my: 'going',
          startsIn: const Duration(hours: 20),
        ),
      if (upcoming >= 2)
        meetupRow(
          'v',
          title: t('Sunset yoga flow', 'يوغا الغروب'),
          my: 'interested',
          startsIn: const Duration(days: 1, hours: 4),
        ),
      meetupRow(
        'a',
        title: t('Sunrise run', 'جري الشروق'),
        minSkill: 1,
        maxSkill: 2,
        faces: faces,
      ),
      meetupRow(
        'b',
        title: t('Hatta trail hike', 'مسير حتّا'),
        going: 31,
        startsIn: const Duration(days: 3),
        minSkill: 3,
        maxSkill: 4,
        faces: faces,
      ),
    ];
  }

  // name: (rows, upcoming count, filters applied)
  final listings = <String, (int, bool)>{
    'default': (1, true),
    'empty': (-1, false),
    'upcoming-single': (1, true),
    'upcoming-multi': (2, true),
  };
  for (final e in listings.entries) {
    for (final l in <Locale>[const Locale('en'), const Locale('ar')]) {
      testWidgets('listing ${e.key} ${l.languageCode}', (tester) async {
        await _shoot(
          tester,
          const MeetupsScreen(),
          FakeMeetupRepository()
            ..nearbyList = nearby
            ..list = e.value.$1 < 0
                ? const <MeetupListItem>[]
                : rows(l.languageCode, upcoming: e.value.$1),
          l,
          'meetups-listing-${e.key}-${l.languageCode}',
          overrides: <Override>[
            if (e.value.$2) meetupRadiusProvider.overrideWith((ref) => 5000),
            if (e.value.$2)
              meetupSortProvider.overrideWith((ref) => MeetupSort.nearest),
          ],
        );
      });
    }
  }

  // Listings v2: the collapsing, accent-tinted header (Meetups = `active`).
  for (final bool filters in <bool>[true, false]) {
    testWidgets('listing v2 ${filters ? 'filters' : 'plain'}', (tester) async {
      final String mode = const String.fromEnvironment('RENDER_DARK') == '1'
          ? 'dark'
          : 'light';
      final String fs = filters ? 'filters' : 'plain';
      final String dir = const String.fromEnvironment(
        'LISTINGS_V2_DIR',
        defaultValue: '$kShotsRoot/listings-v2/app',
      );
      Future<void> shoot(String name) async {
        final key = tester.firstWidget<RepaintBoundary>(
          find.byType(RepaintBoundary),
        );
        await tester.runAsync(() async {
          final boundary =
              tester.renderObject(find.byWidget(key)) as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory(dir).createSync(recursive: true);
          File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      final list = <MeetupListItem>[
        for (var i = 0; i < 6; i++)
          ...rows('en', upcoming: 1).take(1).map((r) => r),
      ];
      await _shoot(
        tester,
        SectionThemed(
          theme: DabblerTheme.active,
          child: const DabblerPage(body: MeetupsScreen()),
        ),
        FakeMeetupRepository()
          ..nearbyList = nearby
          ..list = list,
        const Locale('en'),
        'meetups-v2-$mode-$fs-top',
        overrides: <Override>[
          if (filters) meetupRadiusProvider.overrideWith((ref) => 5000),
          if (filters)
            meetupSortProvider.overrideWith((ref) => MeetupSort.nearest),
        ],
        before: () async => shoot('meetups-$mode-$fs-top'),
      );
      await tester.drag(find.byType(ListView).last, const Offset(0, -240));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await shoot('meetups-$mode-$fs-collapsed');
    });
  }

  for (final l in <Locale>[const Locale('en'), const Locale('ar')]) {
    for (final pick in <String>['yes', 'maybe', 'no']) {
      testWidgets('rsvp sheet $pick ${l.languageCode}', (tester) async {
        final repo = FakeMeetupRepository()
          ..card = _card(
            title: l.languageCode == 'ar' ? 'جري الشروق' : 'Sunrise run',
            my: 'going',
          )
          ..eligibility = const RsvpEligibility(
            allowed: true,
            cta: RsvpCta.already,
          );
        await _shoot(
          tester,
          MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
          repo,
          l,
          'meetups-rsvp-sheet-$pick-${l.languageCode}',
          before: () async {
            await tester.tap(find.byType(DabblerRsvpCta));
            await settle(tester);
            final label = lookupAppLocalizations(l);
            if (pick == 'maybe') {
              await tester.tap(find.text(label.meetups_sheet_maybe));
            } else if (pick == 'no') {
              await tester.tap(find.text(label.meetups_sheet_no));
            }
            await settle(tester);
          },
        );
      });
    }
  }
}
