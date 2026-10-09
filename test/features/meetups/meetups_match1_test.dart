import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/features/home/presentation/widgets/section_themed.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_filters.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_setting.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetups_screen.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import 'meetup_screens_harness.dart';

/// Meetups listing match (Listings.dc.html, Meetups): the Date, Indoor/outdoor
/// and Most popular filters, the setting tag, three faces, and the empty
/// state's sentence. Renders go to `meetups-match1/app` (LTR/RTL x light/dark
/// by `--dart-define=RENDER_DARK=1`).
const String _shotsDir = String.fromEnvironment(
  'MEETUPS_MATCH1_DIR',
  defaultValue: '$kShotsRoot/meetups-match1/app',
);
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

class _Ready extends ActiveLocationNotifier {
  _Ready([this.areaName = 'Dubai Marina']);
  final String areaName;

  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    ActiveLocation(
      lat: 25.2,
      lng: 55.27,
      source: ActiveLocationSource.saved,
      area: Area(
        id: 'a1',
        name: areaName,
        district: 'Marina',
        city: 'Dubai',
        country: 'AE',
        centerLat: 25.2,
        centerLng: 55.27,
      ),
    ),
  );
}

/// The repository answers per sport tab, as the real one does.
class _ByTab extends FakeMeetupRepository {
  @override
  Future<Result<List<MeetupListItem>, Failure>> fetchMeetups({
    String? sportId,
    int limit = 20,
    int offset = 0,
  }) async => Ok(<MeetupListItem>[
    for (final m in list)
      if (sportId == null || m.sportId == sportId) m,
  ]);
}

const List<MeetupAvatar> _faces = <MeetupAvatar>[
  MeetupAvatar(displayName: 'Ahmed Farouk'),
  MeetupAvatar(displayName: 'Lina Haddad'),
  MeetupAvatar(displayName: 'Yousef Amer'),
  MeetupAvatar(displayName: 'Nadia Saleh'),
];

/// Distances the nearby query would return, so the card shows "place · km".
const List<NearbyMeetup> _nearby = <NearbyMeetup>[
  NearbyMeetup(id: 'u', title: 't', distanceM: 4600),
  NearbyMeetup(id: 'a', title: 't', distanceM: 3000),
  NearbyMeetup(id: 'b', title: 't', distanceM: 4200),
  NearbyMeetup(id: 'c', title: 't', distanceM: 5200),
];

/// The fixture's clock (KAN-470): rows and screen read the same fixed instant,
/// so "Today" holds whatever the wall clock says.
final DateTime _fixedNow = DateTime(2030, 1, 15, 12);

MeetupListItem _row(
  String id,
  String title, {
  Duration startsIn = const Duration(days: 1),
  int going = 12,
  String sportId = 's1',
  String sport = 'Running',
  String sportAr = 'جري',
  String? my,
}) => meetupRow(
  id,
  title: title,
  startsIn: startsIn,
  anchor: _fixedNow,
  going: going,
  my: my,
  faces: _faces,
).copyWith(sportId: sportId, sportNameEn: sport, sportNameAr: sportAr);

Future<void> _pump(
  WidgetTester tester,
  FakeMeetupRepository repo,
  Locale locale, {
  List<Override> overrides = const <Override>[],
  Key key = const Key('shot'),
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meetupRepositoryProvider.overrideWithValue(repo),
        meetupClockProvider.overrideWithValue(() => _fixedNow),
        activePersonaProvider.overrideWithValue(PersonaType.player),
        activeLocationProvider.overrideWith(
          () => _Ready(
            locale.languageCode == 'ar' ? 'مارينا دبي' : 'Dubai Marina',
          ),
        ),
        myProfileIdProvider.overrideWith((ref) async => 'me'),
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
        home: SectionThemed(
          theme: DabblerTheme.active,
          child: const DabblerPage(body: MeetupsScreen()),
        ),
      ),
    ),
  );
  await settle(tester);
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(const Key('shot')))
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadRenderFonts);

  group('filters', () {
    final now = DateTime(2026, 10, 7, 12); // a Wednesday
    test('date: today, tomorrow, week and weekend', () {
      bool f(DateTime d, MeetupDateFilter x) => meetupInDateFilter(d, x, now);
      expect(f(DateTime(2026, 10, 7, 23), MeetupDateFilter.today), isTrue);
      expect(f(DateTime(2026, 10, 8, 1), MeetupDateFilter.today), isFalse);
      expect(f(DateTime(2026, 10, 8, 1), MeetupDateFilter.tomorrow), isTrue);
      expect(f(DateTime(2026, 10, 13), MeetupDateFilter.thisWeek), isTrue);
      expect(f(DateTime(2026, 10, 14), MeetupDateFilter.thisWeek), isFalse);
      // Sat 10 Oct is the coming weekend; Mon 12 Oct is not.
      expect(f(DateTime(2026, 10, 10), MeetupDateFilter.thisWeekend), isTrue);
      expect(f(DateTime(2026, 10, 12), MeetupDateFilter.thisWeekend), isFalse);
    });

    test('setting: unknown venue matches neither indoor nor outdoor', () {
      final all = <MeetupListItem>[
        _row('in', 'A'),
        _row('out', 'B'),
        _row('none', 'C'),
      ];
      const settings = <String, bool?>{'in': true, 'out': false, 'none': null};
      List<String> ids(bool? indoor) => [
        for (final m in applyMeetupFilters(
          all,
          distances: const {},
          indoor: indoor,
          settings: settings,
        ))
          m.id,
      ]..sort();
      expect(ids(true), ['in']);
      expect(ids(false), ['out']);
      expect(ids(null), ['in', 'none', 'out']);
    });

    test('most popular orders by going count, then start', () {
      final all = <MeetupListItem>[
        _row('a', 'A', going: 3),
        _row('b', 'B', going: 30),
        _row('c', 'C', going: 10),
      ];
      expect(
        [
          for (final m in applyMeetupFilters(
            all,
            distances: const {},
            sort: MeetupSort.popular,
          ))
            m.id,
        ],
        ['b', 'c', 'a'],
      );
    });
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);
  final String mode = _dark ? 'dark' : 'light';

  for (final (String dir, Locale locale) in <(String, Locale)>[
    ('ltr', const Locale('en')),
    ('rtl', const Locale('ar')),
  ]) {
    final bool ar = dir == 'rtl';
    List<MeetupListItem> rows() => <MeetupListItem>[
      // The viewer is going: it counts down in the Upcoming row.
      _row(
        'u',
        ar ? 'ركوب الفجر' : 'Dawn ride',
        startsIn: const Duration(hours: 20),
        my: 'going',
      ),
      _row(
        'a',
        ar ? 'جري الشروق' : 'Sunrise run',
        startsIn: const Duration(hours: 3),
        going: 24,
      ),
      _row(
        'b',
        ar ? 'مسير حتّا' : 'Hatta trail hike',
        startsIn: const Duration(days: 3),
        going: 31,
      ),
      _row(
        'c',
        ar ? 'يوغا الغروب' : 'Sunset yoga',
        startsIn: const Duration(hours: 9),
        going: 5,
        sportId: 's2',
        sport: 'Yoga',
        sportAr: 'يوغا',
      ),
    ];
    const settings = <String, bool?>{
      'u': null,
      'a': false,
      'b': false,
      'c': null,
    };

    testWidgets('meetups $mode $dir default', (tester) async {
      await _pump(
        tester,
        FakeMeetupRepository()
          ..nearbyList = _nearby
          ..list = rows(),
        locale,
        overrides: [
          meetupSettingsProvider.overrideWith((ref) async => settings),
        ],
      );
      expect(tester.takeException(), isNull);
      // Listings 2026-10-08b: the Favourites heart leads the header actions.
      expect(
        tester
            .widget<DabblerPageHeader>(find.byType(DabblerPageHeader))
            .actions
            .first
            .icon,
        'heart',
      );

      // Setting tag only where the venue is known.
      expect(find.text(ar ? 'خارجي' : 'Outdoor'), findsNWidgets(2));
      // Three faces at most.
      final att = tester.widgetList<DabblerMeetupAttendees>(
        find.byType(DabblerMeetupAttendees),
      );
      expect(att.every((a) => a.maxAvatars == 3), isTrue);
      await _shoot(tester, 'meetups-$dir-default');
    }, variant: desktop);

    testWidgets('meetups $mode $dir filtered', (tester) async {
      await _pump(
        tester,
        FakeMeetupRepository()
          ..nearbyList = _nearby
          ..list = rows(),
        locale,
        overrides: [
          meetupSettingsProvider.overrideWith((ref) async => settings),
          meetupDateProvider.overrideWith((ref) => MeetupDateFilter.today),
          meetupIndoorProvider.overrideWith((ref) => false),
          meetupSortProvider.overrideWith((ref) => MeetupSort.popular),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text(ar ? 'اليوم' : 'Today'), findsWidgets);
      expect(find.text(ar ? 'الأكثر شعبية' : 'Most popular'), findsWidgets);
      // Today + Outdoor leaves the 3-hour run only.
      expect(find.text(ar ? 'جري الشروق' : 'Sunrise run'), findsOneWidget);
      expect(find.text(ar ? 'مسير حتّا' : 'Hatta trail hike'), findsNothing);
      await _shoot(tester, 'meetups-$dir-filtered');
    }, variant: desktop);

    testWidgets('meetups $mode $dir empty', (tester) async {
      await _pump(
        tester,
        _ByTab()
          ..list = <MeetupListItem>[
            _row(
              'c',
              'Sunset yoga',
              sportId: 's2',
              sport: 'Yoga',
              sportAr: 'يوغا',
            ),
          ],
        locale,
        overrides: [
          meetupSettingsProvider.overrideWith((ref) async => settings),
        ],
      );
      // The Running tab has no sessions; Yoga does.
      await tester.tap(find.text(ar ? 'جري' : 'Running').first);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          ar
              ? 'لا توجد لقاءات في جري الآن. توجد جلسات قادمة في يوغا.'
              : 'Running has no meetups right now. Sessions are coming up in Yoga.',
        ),
        findsOneWidget,
      );
      await _shoot(tester, 'meetups-$dir-empty');
    }, variant: desktop);
  }

  testWidgets('filter sheet groups: Distance, Date, Setting, Sort', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeMeetupRepository()..list = <MeetupListItem>[_row('a', 'A')],
      const Locale('en'),
      overrides: [
        meetupSettingsProvider.overrideWith(
          (ref) async => const <String, bool?>{},
        ),
      ],
    );
    await tester.tap(find.bySemanticsLabel('Filters'));
    await settle(tester);
    for (final label in [
      'Distance',
      'Date',
      'Indoor / outdoor',
      'Sort by',
      'Today',
      'Tomorrow',
      'This week',
      'This weekend',
      'Indoor',
      'Outdoor',
      'Nearest',
      'Starting soonest',
      'Most popular',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    await _shoot(tester, 'meetups-ltr-filter-sheet');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
