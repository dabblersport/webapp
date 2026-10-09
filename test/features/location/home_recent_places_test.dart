import 'package:dabbler/core/services/recent_places_service.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-469 home half: the home picker's Recent group lists device recent
/// areas first, then the saved locations unchanged.
const _svc = RecentPlacesService();

Area _area(String id, String name, String district) => Area(
  id: id,
  name: name,
  district: district,
  city: 'Dubai',
  country: 'UAE',
  centerLat: 25.08,
  centerLng: 55.14,
);

final Area _marina = _area('a1', 'Dubai Marina', 'JLT & Marina');
final Area _jbr = _area('a2', 'JBR', 'JLT & Marina');
final Area _downtown = _area('a3', 'Downtown', 'Downtown & DIFC');

final DateTime _t = DateTime(2026, 10, 1);
final List<ProfileLocation> _savedList = <ProfileLocation>[
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

final List<Area> _picked = <Area>[];

class _FakeActive extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    ActiveLocation(
      lat: 25.08,
      lng: 55.14,
      area: _marina,
      source: ActiveLocationSource.gps,
    ),
  );

  @override
  Future<void> useManualArea(Area area) async => _picked.add(area);

  @override
  Future<void> refresh() async {}

  @override
  void setRadiusOverride(int meters) {}
}

class _FakeSaved extends ProfileLocationNotifier {
  _FakeSaved(this.list);
  final List<ProfileLocation> list;

  @override
  Future<List<ProfileLocation>> build() async => list;

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

/// Pumps a page with an `open` button that calls
/// [HomeLocationPickerSheet.show].
Future<void> _host(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  String? userId = 'u1',
  List<ProfileLocation>? saved,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(_FakeActive.new),
        profileLocationNotifierProvider.overrideWith(
          () => _FakeSaved(saved ?? _savedList),
        ),
        areaRepositoryV2Provider.overrideWithValue(_FakeAreaRepo()),
        currentUserIdProvider.overrideWithValue(userId),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        builder: (context, child) => DabblerToastProvider(child: child!),
        home: DabblerPage(
          body: Builder(
            builder: (context) => Center(
              child: DabblerButton(
                label: 'open',
                onPressed: () => HomeLocationPickerSheet.show(context),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await _settle(tester);
}

/// Row titles in paint order.
List<String> _titles(WidgetTester tester) => tester
    .widgetList<DabblerListRow>(find.byType(DabblerListRow))
    .map((r) => r.title)
    .toList();

const _empty = Key('home-location-recent-empty');

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _picked.clear();
  });

  testWidgets('shows saved locations exactly as before when there are no '
      'recents', (tester) async {
    final l = lookupAppLocalizations(const Locale('en'));
    await _host(tester);
    await _open(tester);
    expect(find.byKey(_empty), findsNothing);
    expect(_titles(tester), [
      l.home_location_use_current,
      'Home',
      'Work',
      l.home_location_add,
      'Dubai Marina',
      'JBR',
      'Downtown',
    ]);
  });

  testWidgets('shows recents FIRST then saved locations after a pick on next '
      'open; the sheet still hands the picked area to useManualArea', (
    tester,
  ) async {
    final l = lookupAppLocalizations(const Locale('en'));
    await _host(tester);
    await _open(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('JBR'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await _settle(tester);
    expect(_picked.single, _jbr);
    expect((await tester.runAsync(() => _svc.readAreas('u1')))!.single, _jbr);

    await _open(tester);
    expect(_titles(tester), [
      l.home_location_use_current,
      'JBR',
      'Home',
      'Work',
      l.home_location_add,
      'Dubai Marina',
      'JBR',
      'Downtown',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking an area from search records it', (tester) async {
    await _host(tester);
    await _open(tester);
    await tester.enterText(find.byType(EditableText), 'JB');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await tester.tap(find.text('JBR'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await _settle(tester);
    expect(_picked.single, _jbr);
    expect(
      (await tester.runAsync(() => _svc.readAreas('u1')))!.single.id,
      'a2',
    );
  });

  testWidgets('empty state shows only when both are empty', (tester) async {
    await _host(tester, saved: const <ProfileLocation>[]);
    await _open(tester);
    expect(find.byKey(_empty), findsOne);
  });

  testWidgets('no empty state when only recents exist', (tester) async {
    await _svc.addArea('u1', _jbr);
    await _host(tester, saved: const <ProfileLocation>[]);
    await _open(tester);
    expect(find.byKey(_empty), findsNothing);
    expect(find.text('JBR'), findsNWidgets(2));
  });

  testWidgets('user B does not see user A recents', (tester) async {
    await _svc.addArea('uA', _jbr);
    await _host(tester, userId: 'uB');
    await _open(tester);
    // Only the browse row, no recent row.
    expect(find.text('JBR'), findsOne);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('Recent group builds without overflow - '
        '${locale.languageCode}', (tester) async {
      for (var i = 1; i <= 25; i++) {
        await _svc.addArea(
          'u1',
          _area('r$i', 'منطقة دبي مارينا الطويلة جدا Long Area Name $i', 'D'),
        );
      }
      await _host(tester, locale: locale);
      await _open(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(_empty), findsNothing);
    });
  }
}
