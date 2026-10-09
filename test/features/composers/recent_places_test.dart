import 'package:dabbler/core/services/recent_places_service.dart';
import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

const _svc = RecentPlacesService();

RecentPlace _p(int i) => RecentPlace(name: 'Place $i', venueId: 'v$i');

const List<Map<String, dynamic>> _venues = [
  {'id': 'v1', 'name': 'Nad Al Sheba Sports Complex', 'city': 'Nad Al Sheba'},
];

Future<void> _host(WidgetTester tester, Locale locale, String? userId) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        venueSearchProvider.overrideWith((ref, q) async => _venues),
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
          body: Consumer(
            builder: (context, ref, _) {
              // Keeps the auto-disposed composer state alive, as the
              // composer screen does.
              ref.watch(postComposerProvider);
              return Center(
                child: DabblerButton(
                  label: 'open',
                  onPressed: () => showComposerPlaceSheet(context, ref),
                ),
              );
            },
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RecentPlacesService', () {
    test('empty store returns empty', () async {
      expect(await _svc.read('a'), isEmpty);
      expect(await _svc.read(null), isEmpty);
    });

    test('adds newest first', () async {
      await _svc.add('a', _p(1));
      await _svc.add('a', _p(2));
      expect((await _svc.read('a')).map((e) => e.name), ['Place 2', 'Place 1']);
    });

    test('de-duplicates by identity (moves to front)', () async {
      await _svc.add('a', _p(1));
      await _svc.add('a', _p(2));
      await _svc.add('a', const RecentPlace(name: 'Renamed', venueId: 'v1'));
      await _svc.add(
        'a',
        const RecentPlace(name: 'Park', lat: 25.1, lng: 55.2),
      );
      await _svc.add(
        'a',
        const RecentPlace(name: ' park ', lat: 25.10001, lng: 55.20001),
      );
      final names = (await _svc.read('a')).map((e) => e.name).toList();
      expect(names, [' park ', 'Renamed', 'Place 2']);
    });

    test('is capped at 25 (adding 30 keeps 25, newest first)', () async {
      for (var i = 1; i <= 30; i++) {
        await _svc.add('a', _p(i));
      }
      final list = await _svc.read('a');
      expect(RecentPlacesService.maxRecent, 25);
      expect(list.length, 25);
      expect(list.first.name, 'Place 30');
      expect(list.last.name, 'Place 6');
    });

    test('per user: B does not see A, A sees them on re-read', () async {
      await _svc.add('a', _p(1));
      expect(await _svc.read('b'), isEmpty);
      expect((await _svc.read('a')).single.venueId, 'v1');
      await _svc.add(null, _p(9));
      expect(await _svc.read('a'), hasLength(1));
    });

    test('clear and sign-out clearAll remove recents', () async {
      await _svc.add('a', _p(1));
      await _svc.add('b', _p(2));
      await _svc.clear('a');
      expect(await _svc.read('a'), isEmpty);
      expect(await _svc.read('b'), hasLength(1));
      await _svc.clearAll();
      expect(await _svc.read('b'), isEmpty);
    });
  });

  group('RecentPlacesService home scope', () {
    Area a(int i) => Area(
      id: 'a$i',
      name: 'Area $i',
      district: 'D',
      city: 'Dubai',
      country: 'UAE',
      centerLat: 25,
      centerLng: 55,
    );

    test('home scope adds newest first', () async {
      await _svc.addArea('a', a(1));
      await _svc.addArea('a', a(2));
      expect((await _svc.readAreas('a')).map((e) => e.id), ['a2', 'a1']);
      expect((await _svc.readAreas('a')).first, a(2));
    });

    test('home scope de-dupes by area identity', () async {
      await _svc.addArea('a', a(1));
      await _svc.addArea('a', a(2));
      await _svc.addArea('a', a(1).copyWith(name: 'Renamed'));
      final list = await _svc.readAreas('a');
      expect(list.map((e) => e.name), ['Renamed', 'Area 2']);
    });

    test('home scope is capped at 25', () async {
      for (var i = 1; i <= 30; i++) {
        await _svc.addArea('a', a(i));
      }
      final list = await _svc.readAreas('a');
      expect(list.length, 25);
      expect(list.first.id, 'a30');
      expect(list.last.id, 'a6');
    });

    test('home scope is per user', () async {
      await _svc.addArea('a', a(1));
      expect(await _svc.readAreas('b'), isEmpty);
      expect(await _svc.readAreas(null), isEmpty);
      await _svc.addArea(null, a(2));
      expect(await _svc.readAreas('a'), hasLength(1));
    });

    test('composer scope unaffected by the home scope', () async {
      await _svc.add('a', _p(1));
      await _svc.addArea('a', a(1));
      expect((await _svc.read('a')).single.venueId, 'v1');
      expect((await _svc.readAreas('a')).single.id, 'a1');
      expect(
        RecentPlacesService.keyFor('a'),
        isNot(RecentPlacesService.homeKeyFor('a')),
      );
    });

    test('clearAll clears both scopes', () async {
      await _svc.add('a', _p(1));
      await _svc.addArea('a', a(1));
      await _svc.addArea('b', a(2));
      await _svc.clearAll();
      expect(await _svc.read('a'), isEmpty);
      expect(await _svc.readAreas('a'), isEmpty);
      expect(await _svc.readAreas('b'), isEmpty);
    });
  });

  group('composer place sheet Recent', () {
    setUpAll(() async {
      await initHomeTestSupabase();
      await loadRenderFonts();
    });

    testWidgets('shows empty state, then the picked place first on next open', (
      tester,
    ) async {
      final l = lookupAppLocalizations(const Locale('en'));
      await _svc.add('u1', const RecentPlace(name: 'Older Pitch'));
      await _host(tester, const Locale('en'), 'u2');
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(find.byKey(const Key('composer-place-recent-empty')), findsOne);
      expect(find.text('Older Pitch'), findsNothing);

      await tester.enterText(find.byType(EditableText), 'Nad');
      await _settle(tester);
      await tester.tap(find.text('Nad Al Sheba Sports Complex'));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text(l.composer_confirm));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await _settle(tester);
      expect(
        (await tester.runAsync(() => _svc.read('u2')))!.first.venueId,
        'v1',
      );

      await tester.tap(find.text('open'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await _settle(tester);
      expect(
        find.byKey(const Key('composer-place-recent-empty')),
        findsNothing,
      );
      final rows = find.byType(ComposerPickerRow);
      // Row 0 is "Use current location"; the first Recent row follows.
      final first = tester.widget<ComposerPickerRow>(rows.at(1));
      expect(first.title, 'Nad Al Sheba Sports Complex');
      await tester.tap(rows.at(1));
      await tester.pump();
      expect(tester.widget<ComposerPickerRow>(rows.at(1)).selected, isTrue);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('Recent group builds without overflow — '
          '${locale.languageCode}', (tester) async {
        for (var i = 1; i <= 25; i++) {
          await _svc.add(
            'u1',
            RecentPlace(
              name: 'ملعب ند الشبا الرياضي الطويل جدا Sports Complex $i',
              venueId: 'v$i',
            ),
          );
        }
        await _host(tester, locale, 'u1');
        await tester.tap(find.text('open'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(ComposerPickerRow), findsWidgets);
        expect(
          find.byKey(const Key('composer-place-recent-empty')),
          findsNothing,
        );
      });
    }
  });
}
