import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/features/home/presentation/widgets/section_themed.dart';
import 'package:dabbler/features/location/presentation/widgets/city_required_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/listing_city.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_filters.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetups_screen.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import 'meetup_screens_harness.dart';

/// KAN-588 on Meetups: no city -> "Choose city" and "Select city"; a city ->
/// that city's meetups (matched by area), A to Z when only the city is known;
/// a change of city leaves nothing of the old one.
class _Loc extends ActiveLocationNotifier {
  _Loc(this.initial);
  final ActiveLocationState initial;

  @override
  Future<ActiveLocationState> build() async => initial;

  void set(ActiveLocationState s) => state = AsyncData(s);
}

final DateTime _now = DateTime(2030, 1, 15, 12);

MeetupListItem _row(String id, String title, String? areaId, int days) =>
    meetupRow(
      id,
      title: title,
      startsIn: Duration(days: days),
      anchor: _now,
    ).copyWith(areaId: areaId);

Future<void> _pump(
  WidgetTester tester,
  FakeMeetupRepository repo,
  ActiveLocationState location, {
  bool areasFail = false,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meetupRepositoryProvider.overrideWithValue(repo),
        meetupClockProvider.overrideWithValue(() => _now),
        activePersonaProvider.overrideWithValue(PersonaType.player),
        activeLocationProvider.overrideWith(() => _Loc(location)),
        myProfileIdProvider.overrideWith((ref) async => 'me'),
        listingCityAreaIdsProvider.overrideWith((ref, city) async {
          if (areasFail) throw Exception('areas offline');
          return city.name == 'Dubai'
              ? <String>['a-dubai']
              : <String>['a-doha'];
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: const Locale('en'),
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

void main() {
  setUpAll(loadRenderFonts);

  testWidgets('no city: Choose city, and Select city opens the picker', (
    tester,
  ) async {
    await _pump(tester, FakeMeetupRepository(), ActiveLocationDenied());
    expect(find.text('Choose city'), findsOneWidget);
    expect(find.text('Select city'), findsOneWidget);

    await tester.tap(find.text('Select city'));
    await settle(tester);
    expect(find.byType(CityRequiredSheet), findsOneWidget);
  });

  testWidgets('only a city: that city\'s meetups, A to Z', (tester) async {
    final repo = FakeMeetupRepository()
      ..list = <MeetupListItem>[
        _row('m1', 'Zumba on the beach', 'a-dubai', 1),
        _row('m2', 'Aikido basics', 'a-dubai', 3),
        _row('m3', 'Doha padel night', 'a-doha', 2),
      ];
    await _pump(tester, repo, ActiveLocationCityOnly('Dubai', country: 'AE'));
    expect(find.text('Doha padel night'), findsNothing);
    final aikido = tester.getTopLeft(find.text('Aikido basics')).dy;
    final zumba = tester.getTopLeft(find.text('Zumba on the beach')).dy;
    expect(aikido, lessThan(zumba));
  });

  testWidgets('a change of city shows none of the old city\'s meetups', (
    tester,
  ) async {
    final repo = FakeMeetupRepository()
      ..list = <MeetupListItem>[
        _row('m1', 'Dubai beach run', 'a-dubai', 1),
        _row('m3', 'Doha padel night', 'a-doha', 2),
      ];
    await _pump(tester, repo, ActiveLocationCityOnly('Dubai', country: 'AE'));
    expect(find.text('Dubai beach run'), findsOneWidget);

    final c = ProviderScope.containerOf(
      tester.element(find.byType(MeetupsScreen)),
    );
    (c.read(activeLocationProvider.notifier) as _Loc).set(
      ActiveLocationCityOnly('Doha', country: 'QA'),
    );
    await settle(tester);
    expect(find.text('Dubai beach run'), findsNothing);
    expect(find.text('Doha padel night'), findsOneWidget);
  });

  testWidgets('the city\'s Areas fail to load: an error, not an empty city', (
    tester,
  ) async {
    final repo = FakeMeetupRepository()
      ..list = <MeetupListItem>[_row('m1', 'Dubai beach run', 'a-dubai', 1)];
    await _pump(
      tester,
      repo,
      ActiveLocationCityOnly('Dubai', country: 'AE'),
      areasFail: true,
    );
    expect(find.text('Dubai beach run'), findsNothing);
    expect(find.text('Choose city'), findsNothing);
    expect(find.text('Retry'), findsWidgets);
  });

  testWidgets('an Area is chosen: the city\'s meetups, soonest first', (
    tester,
  ) async {
    final repo = FakeMeetupRepository()
      ..list = <MeetupListItem>[
        _row('m1', 'Zumba on the beach', 'a-dubai', 1),
        _row('m2', 'Aikido basics', 'a-dubai', 3),
      ];
    await _pump(
      tester,
      repo,
      ActiveLocationReady(
        const ActiveLocation(
          lat: 25.2,
          lng: 55.3,
          area: Area(
            id: 'a-dubai',
            name: 'Al Barsha',
            district: 'Dubai',
            city: 'Dubai',
            country: 'AE',
            centerLat: 25.2,
            centerLng: 55.3,
          ),
          source: ActiveLocationSource.manual,
        ),
      ),
    );
    final zumba = tester.getTopLeft(find.text('Zumba on the beach')).dy;
    final aikido = tester.getTopLeft(find.text('Aikido basics')).dy;
    expect(zumba, lessThan(aikido));
  });
}
