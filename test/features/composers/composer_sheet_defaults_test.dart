import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_game_link_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_vibes_sheet.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:mockito/mockito.dart';

import '../../support/render_mode.dart';
import 'composer_locate_test.mocks.dart';
import '../home/home_test_harness.dart';

/// KAN-463: the Create Post sheets' defaults per `Home Feed.dc.html` —
/// vibes per post kind with their count, the place sheet's "Use current
/// location" + Recent before typing, the game sheet's joined games before
/// typing. Writes PNGs only with `--dart-define=SHEET_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('SHEET_SHOTS_DIR');
const Key _key = Key('shot');

Future<void> _shoot(WidgetTester tester, String name) async {
  if (_shotsDir.isEmpty) return;
  const theme = String.fromEnvironment('RENDER_DARK') == '1' ? 'dark' : 'light';
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(_key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File(
      '$_shotsDir/$name-$theme.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// The live vibe catalogue as a fixture: every design vibe (key + label).
final List<Vibe> _vibes = [
  for (final v in DabblerVibe.values)
    Vibe(id: v.key, key: v.key, labelEn: v.label, labelAr: v.label),
  // A key the design does not know: offered for no kind.
  const Vibe(id: 'x', key: 'not-in-design', labelEn: 'Unknown', labelAr: ''),
];

/// Counts per kind from `Home Feed.dc.html` VIBES `contexts`
/// (kind_vibes_design.md).
const Map<PostType, int> _designCounts = {
  PostType.moment: 68,
  PostType.dab: 50,
  PostType.kickIn: 55,
};

const List<Map<String, dynamic>> _venues = [
  {'id': 'v1', 'name': 'Nad Al Sheba Sports Complex', 'city': 'Nad Al Sheba'},
  {'id': 'v2', 'name': 'Al Warqa Practice Nets', 'city': 'Al Warqa'},
];

final List<Map<String, dynamic>> _joined = [
  {
    'id': 'j1',
    'title': 'Friday 5-a-side',
    'sport': 'football',
    'start_at': DateTime(2026, 8, 18, 20).toIso8601String(),
  },
  {
    'id': 'j2',
    'title': 'Padel doubles',
    'sport': 'padel',
    'start_at': DateTime(2026, 8, 19, 19).toIso8601String(),
  },
  {
    'id': 'j3',
    'title': 'Thursday nets + match',
    'sport': 'cricket',
    'start_at': DateTime(2026, 8, 20, 18).toIso8601String(),
  },
];

final List<Map<String, dynamic>> _searched = [
  {
    'id': 's1',
    'title': 'Sunday morning run',
    'sport': 'running',
    'start_at': DateTime(2026, 8, 23, 6, 30).toIso8601String(),
  },
];

Future<ProviderContainer> _host(
  WidgetTester tester,
  Locale locale,
  void Function(BuildContext, WidgetRef) open, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        venueSearchProvider.overrideWith((ref, q) async => _venues),
        gameSearchProvider.overrideWith((ref, q) async => _searched),
        composerJoinedGamesProvider.overrideWith((ref) async => _joined),
        vibesProvider.overrideWith((ref) async => _vibes),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: _key, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: DabblerPage(
          body: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              ref.watch(vibesProvider);
              ref.watch(postComposerProvider);
              return Center(
                child: DabblerButton(
                  label: 'open',
                  onPressed: () => open(context, ref),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  test('design list matches the design-system contexts', () {
    for (final e in _designCounts.entries) {
      expect(composerVibesFor(_vibes, e.key).length, e.value, reason: '$e');
    }
    // A kind with no design context is left unfiltered.
    expect(composerVibesFor(_vibes, PostType.allocated).length, _vibes.length);
    expect(composerVibesFor(_vibes, null).length, _vibes.length);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final lang = locale.languageCode;
    final l = lookupAppLocalizations(locale);
    String kindLabel(PostType t) => switch (t) {
      PostType.moment => l.composer_type_moment,
      PostType.dab => l.composer_type_dab,
      _ => l.composer_type_kickin,
    };

    for (final kind in _designCounts.keys) {
      testWidgets('vibes for ${kind.name} — $lang', (tester) async {
        Vibe? confirmed;
        var cleared = 0;
        await _host(
          tester,
          locale,
          (context, ref) => showComposerVibesSheet(
            context,
            ref,
            selectedVibeId: null,
            kindLabel: kindLabel(kind),
            postType: kind,
            onConfirm: (v) => confirmed = v,
            onClear: () => cleared++,
          ),
        );
        await _open(tester);
        expect(tester.takeException(), isNull);
        final n = _designCounts[kind]!;
        final chips = find.byType(DabblerChip, skipOffstage: false);
        expect(chips, findsNWidgets(n));
        final label = lang == 'en'
            ? kindLabel(kind).toLowerCase()
            : kindLabel(kind);
        expect(find.text(l.composer_vibe_count(n, label)), findsOneWidget);
        // Exactly the designed subset.
        final shown = tester
            .widgetList<DabblerChip>(chips)
            .map((c) => c.vibe?.key)
            .toSet();
        final ctx = composerVibeContext(kind)!;
        expect(shown, {
          for (final v in DabblerVibe.values)
            if (v.contexts.contains(ctx)) v.key,
        });
        expect(find.text('Unknown'), findsNothing);
        await _shoot(tester, 'vibes-${kind.name}-$lang');

        // Selection and Clear still behave.
        await tester.tap(chips.first);
        await tester.pump();
        await tester.tap(find.text(l.composer_confirm));
        await _settle(tester);
        expect(confirmed, isNotNull);
        expect(shown, contains(confirmed!.key));
        await _open(tester);
        await tester.tap(find.text(l.composer_clear).first);
        await _settle(tester);
        expect(cleared, 1);
      });
    }

    testWidgets('place sheet: default, then results — $lang', (tester) async {
      final c = await _host(
        tester,
        locale,
        (context, ref) => showComposerPlaceSheet(context, ref),
      );
      await _open(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l.home_location_use_current), findsOneWidget);
      expect(find.text(l.home_location_recent), findsOneWidget);
      expect(find.text(l.composer_place_recent_empty), findsOneWidget);
      expect(find.text(l.composer_place_location_denied), findsNothing);
      expect(find.text(l.composer_results), findsNothing);
      expect(find.text('Nad Al Sheba Sports Complex'), findsNothing);
      await _shoot(tester, 'place-default-$lang');

      await tester.enterText(find.byType(EditableText), 'Nad');
      await _settle(tester);
      expect(find.text(l.home_location_use_current), findsNothing);
      expect(find.text(l.home_location_recent), findsNothing);
      expect(find.text(l.composer_place_recent_empty), findsNothing);
      expect(find.text(l.composer_results), findsOneWidget);
      expect(find.text('Nad Al Sheba Sports Complex'), findsOneWidget);
      await _shoot(tester, 'place-typed-$lang');

      // Selection, then Clear.
      await tester.tap(find.text('Nad Al Sheba Sports Complex'));
      await tester.pump();
      await tester.tap(find.text(l.composer_confirm));
      await _settle(tester);
      expect(c.read(postComposerProvider).venueId, 'v1');
      await _open(tester);
      await tester.tap(find.text(l.composer_clear).first);
      await _settle(tester);
      expect(c.read(postComposerProvider).locationName, isNull);
    });

    testWidgets('place sheet: use current location commits — $lang', (
      tester,
    ) async {
      final gps = MockGpsService();
      final areas = MockAreaRepository();
      when(gps.getCurrentLocation()).thenAnswer(
        (_) async => LocationSuccess(lat: 25.2, lng: 55.3, accuracyMeters: 5),
      );
      when(areas.resolveNearest(25.2, 55.3)).thenAnswer(
        (_) async => const Area(
          id: 'area-1',
          name: 'Dubai Marina',
          district: 'Dubai',
          city: 'Dubai',
          country: 'AE',
          centerLat: 25.2,
          centerLng: 55.3,
        ),
      );
      final c = await _host(
        tester,
        locale,
        (context, ref) => showComposerPlaceSheet(context, ref),
        overrides: [
          gpsServiceProvider.overrideWithValue(gps),
          areaRepositoryV2Provider.overrideWithValue(areas),
        ],
      );
      await _open(tester);
      await tester.tap(find.text(l.home_location_use_current));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      // The sheet closed with the place committed, as a confirmed pick does.
      expect(find.text(l.home_location_use_current), findsNothing);
      final s = c.read(postComposerProvider);
      expect(s.locationName, 'Dubai Marina');
      expect(s.locationTagId, 'area-1');
      expect(s.geoLat, 25.2);
      expect(s.geoLng, 55.3);
    });

    testWidgets('place sheet: denied shows the inline message — $lang', (
      tester,
    ) async {
      final gps = MockGpsService();
      final areas = MockAreaRepository();
      when(gps.getCurrentLocation()).thenAnswer((_) async => LocationDenied());
      final c = await _host(
        tester,
        locale,
        (context, ref) => showComposerPlaceSheet(context, ref),
        overrides: [
          gpsServiceProvider.overrideWithValue(gps),
          areaRepositoryV2Provider.overrideWithValue(areas),
        ],
      );
      await _open(tester);
      await tester.tap(find.text(l.home_location_use_current));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      // Still open, nothing set, inline message shown.
      expect(find.text(l.home_location_use_current), findsOneWidget);
      expect(find.text(l.composer_place_location_denied), findsOneWidget);
      expect(c.read(postComposerProvider).locationName, isNull);
      verifyNever(areas.resolveNearest(any, any));
      await _shoot(tester, 'place-denied-$lang');
    });

    testWidgets('game sheet: joined games, then search — $lang', (
      tester,
    ) async {
      final c = await _host(
        tester,
        locale,
        (context, ref) => showComposerGameLinkSheet(context, ref),
      );
      await _open(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l.composer_games_joined_hint), findsOneWidget);
      expect(find.byType(DabblerGameLinkRow), findsNWidgets(3));
      expect(find.text('Friday 5-a-side'), findsOneWidget);
      await _shoot(tester, 'game-default-$lang');

      await tester.enterText(find.byType(EditableText), 'Sun');
      await _settle(tester);
      expect(find.byType(DabblerGameLinkRow), findsOneWidget);
      expect(find.text('Sunday morning run'), findsOneWidget);
      expect(find.text('Friday 5-a-side'), findsNothing);
      await _shoot(tester, 'game-typed-$lang');

      await tester.tap(find.text('Sunday morning run'));
      await tester.pump();
      await tester.tap(find.text(l.composer_confirm));
      await _settle(tester);
      expect(c.read(postComposerProvider).gameId, 's1');
      await _open(tester);
      await tester.tap(find.text(l.composer_clear).first);
      await _settle(tester);
      expect(c.read(postComposerProvider).gameId, isNull);
    });
  }
}
