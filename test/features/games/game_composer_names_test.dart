import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_names.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_parts.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_sheet_page.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/render_mode.dart';

/// KAN-484: in Arabic the Create game format, venue and space names show
/// `name_ar` (falling back to `name_en` when it is null or empty), the sheet
/// search also matches the Arabic names, and the duration chips are the ARB
/// sentences. Ids, `variant_key` and what goes to the server do not change.
/// The database is a fake HTTP client. Renders: `--dart-define=KAN484_SHOTS=<dir>`.
const String _shots = String.fromEnvironment('KAN484_SHOTS');
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

const List<Map<String, dynamic>> _sports = <Map<String, dynamic>>[
  {
    'id': 's-padel',
    'sport_key': 'padel',
    'name_en': 'Padel',
    'name_ar': 'بادل',
    'emoji': '🎾',
    'color_code': null,
  },
];

const List<Map<String, dynamic>> _variants = <Map<String, dynamic>>[
  {
    'id': 'v-doubles',
    'variant_key': 'doubles',
    'name_en': 'Doubles',
    'name_ar': 'زوجي',
    'required_players': 4,
    'players_per_side': 2,
  },
  {
    // No Arabic name in the database: falls back to English.
    'id': 'v-singles',
    'variant_key': 'singles',
    'name_en': 'Singles',
    'name_ar': null,
    'required_players': 2,
    'players_per_side': 1,
  },
];

const List<Map<String, dynamic>> _spaces = <Map<String, dynamic>>[
  {
    'id': 'vs-1',
    'name_en': 'Court 1',
    'name_ar': 'ملعب الأول',
    'sport_id': 's-padel',
    'sport_variant_keys': ['doubles', 'singles'],
    'venue': {
      'id': 'ven-1',
      'name_en': 'Padel Pro',
      'name_ar': 'بادل برو',
      'area': 'Marina',
    },
  },
  {
    'id': 'vs-2',
    'name_en': 'Court 2',
    'name_ar': '',
    'sport_id': 's-padel',
    'sport_variant_keys': ['doubles', 'singles'],
    'venue': {
      'id': 'ven-2',
      'name_en': 'City Club',
      'name_ar': null,
      'area': 'Downtown',
    },
  },
];

final List<(String, Map<String, dynamic>)> _rpc =
    <(String, Map<String, dynamic>)>[];

http.Client _fakeDb() => MockClient((http.Request req) async {
  http.Response json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    request: req,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
  final String path = req.url.path;
  if (path.endsWith('/rpc/check_and_bump_cooldown')) {
    return json(<Object>[
      <String, Object>{
        'allowed': true,
        'remaining': 4,
        'reset_at': '2026-12-01T00:00:00Z',
      },
    ]);
  }
  if (path.contains('/rpc/')) {
    _rpc.add((
      path.split('/').last,
      jsonDecode(req.body) as Map<String, dynamic>,
    ));
    return json('g-new');
  }
  if (path.endsWith('/sports')) return json(_sports);
  if (path.endsWith('/sport_variants')) return json(_variants);
  if (path.endsWith('/venue_spaces')) return json(_spaces);
  return json(<Object>[]);
});

Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ThemeData _theme(Locale locale) => DabblerDesignSystemTheme.withFonts(
  DabblerDesignSystemTheme.withTokens(renderThemeBase()),
  locale: locale,
);

Future<void> _pump(
  WidgetTester tester,
  Widget body,
  Locale locale, {
  PersonaType persona = PersonaType.player,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activePersonaProvider.overrideWithValue(persona)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: const Key('shot'), child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: _theme(locale),
        // A parent page under the composer, so its `context.pop(true)` on
        // success has somewhere to return to.
        routerConfig: GoRouter(
          initialLocation: '/c',
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (context, state) => const SizedBox.shrink(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'c',
                  builder: (context, state) => Builder(
                    builder: (context) => ColoredBox(
                      color: DabblerColors.of(context).bgSecondary,
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _shoot(WidgetTester tester, String name) async {
  if (_shots.isEmpty) return;
  await tester.runAsync(() async {
    final b =
        tester.renderObject(find.byKey(const Key('shot')))
            as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shots).createSync(recursive: true);
    File('$_shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

/// The DabblerSheet the Create game route pushes (GameComposerSheetPage),
/// built inline for a test with no route.
Widget _gameSheet(Widget child, {bool editing = false}) => Builder(
  builder: (context) => DabblerSheet(
    onClose: () => Navigator.of(context).maybePop(),
    detent: DabblerSheetDetent.content,
    contentMaxFraction: DabblerSheet.contentMaxFractionFull,
    pageBackground: true,
    showCloseButton: false,
    titleWidget: GameComposerSheetTitle(editing: editing),
    headerAction: GameComposerCancel(
      onPressed: () => Navigator.of(context).maybePop(),
    ),
    child: child,
  ),
);

Finder _pill(String label) =>
    find.byWidgetPredicate((w) => w is GameSelectPill && w.label == label);

GamePillState _pillState(WidgetTester tester, String label) =>
    tester.widget<GameSelectPill>(_pill(label)).state;

void main() {
  group('gameLocalizedName', () {
    test('Arabic shows name_ar when it is present', () {
      expect(
        gameLocalizedName(
          languageCode: 'ar',
          nameEn: 'Doubles',
          nameAr: 'زوجي',
        ),
        'زوجي',
      );
    });

    test('Arabic falls back to name_en when name_ar is null', () {
      expect(
        gameLocalizedName(languageCode: 'ar', nameEn: 'Doubles', nameAr: null),
        'Doubles',
      );
    });

    test('Arabic falls back to name_en when name_ar is empty or blank', () {
      expect(
        gameLocalizedName(languageCode: 'ar', nameEn: 'Doubles', nameAr: ''),
        'Doubles',
      );
      expect(
        gameLocalizedName(languageCode: 'ar', nameEn: 'Doubles', nameAr: '  '),
        'Doubles',
      );
    });

    test('English always shows name_en, even when name_ar exists', () {
      expect(
        gameLocalizedName(
          languageCode: 'en',
          nameEn: 'Doubles',
          nameAr: 'زوجي',
        ),
        'Doubles',
      );
    });

    test('a missing name_en with no Arabic name is null', () {
      expect(
        gameLocalizedName(languageCode: 'ar', nameEn: null, nameAr: null),
        isNull,
      );
    });

    test('gameRowName reads name_en / name_ar from a row', () {
      const row = <String, dynamic>{
        'name_en': 'Court 1',
        'name_ar': 'ملعب الأول',
      };
      expect(gameRowName(row, 'ar'), 'ملعب الأول');
      expect(gameRowName(row, 'en'), 'Court 1');
      expect(gameRowName(null, 'ar'), isNull);
    });

    test('search matches the English and the Arabic name', () {
      const row = <String, dynamic>{
        'name_en': 'Padel Pro',
        'name_ar': 'بادل برو',
      };
      expect(gameRowNameMatches(row, 'padel'), isTrue);
      expect(gameRowNameMatches(row, 'برو'), isTrue);
      expect(gameRowNameMatches(row, 'xyz'), isFalse);
      expect(
        gameRowNameMatches(const <String, dynamic>{'name_en': 'A'}, 'برو'),
        isFalse,
      );
    });
  });

  group('Create game, widgets', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
        httpClient: _fakeDb(),
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
          autoRefreshToken: false,
        ),
      );
      await loadRenderFonts();
    });

    setUp(_rpc.clear);

    final String mode = _dark ? 'dark' : 'light';

    for (final (String dir, Locale locale) in <(String, Locale)>[
      ('en', const Locale('en')),
      ('ar', const Locale('ar')),
    ]) {
      final l = lookupAppLocalizations(locale);
      final bool ar = dir == 'ar';
      final String padel = ar ? 'بادل' : 'Padel';

      testWidgets('duration chips are the ARB sentences - $dir', (
        tester,
      ) async {
        await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
        expect(find.text(l.game_duration_chip_minutes(30)), findsOneWidget);
        expect(find.text(l.game_duration_chip_hours(1)), findsOneWidget);
        expect(find.text(l.game_duration_chip_hours(2)), findsOneWidget);
        expect(find.text(ar ? '30 د' : '30m'), findsOneWidget);
        if (ar) {
          expect(find.text('30m'), findsNothing);
          expect(find.text('1h'), findsNothing);
        }
        await _shoot(tester, 'chips-$dir-$mode');
      });

      testWidgets('format and venue names follow the locale - $dir', (
        tester,
      ) async {
        await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
        await _tap(tester, find.text(padel));
        await _tap(tester, _pill(l.game_select_format));
        // Rows: Arabic names (Singles has none, so English).
        expect(find.text(ar ? 'زوجي' : 'Doubles'), findsOneWidget);
        expect(find.text('Singles'), findsOneWidget);
        if (ar) expect(find.text('Doubles'), findsNothing);
        await _shoot(tester, 'format-sheet-$dir-$mode');
        await _tap(tester, find.text(ar ? 'زوجي' : 'Doubles'));
        await _tap(tester, find.text(l.composer_confirm));
        // The chosen format chip.
        expect(
          _pillState(tester, ar ? 'زوجي' : 'Doubles'),
          GamePillState.chosen,
        );

        await _tap(tester, _pill(l.composer_select));
        // Venue rows: name_ar when present, else English (null / empty).
        expect(
          find.text(ar ? 'بادل برو · ملعب الأول' : 'Padel Pro · Court 1'),
          findsOneWidget,
        );
        expect(find.text('City Club · Court 2'), findsOneWidget);
        await _shoot(tester, 'venue-sheet-$dir-$mode');

        // Search finds a venue by its Arabic or English name, in either locale.
        final Finder search = find.byWidgetPredicate(
          (w) =>
              w is DabblerTextField &&
              w.placeholder == l.game_venue_search_placeholder,
        );
        await tester.enterText(
          find.descendant(of: search, matching: find.byType(EditableText)),
          'برو',
        );
        await _settle(tester);
        expect(
          find.text(ar ? 'بادل برو · ملعب الأول' : 'Padel Pro · Court 1'),
          findsOneWidget,
        );
        expect(find.text('City Club · Court 2'), findsNothing);
        await tester.enterText(
          find.descendant(of: search, matching: find.byType(EditableText)),
          'city',
        );
        await _settle(tester);
        expect(find.text('City Club · Court 2'), findsOneWidget);
        expect(
          find.text(ar ? 'بادل برو · ملعب الأول' : 'Padel Pro · Court 1'),
          findsNothing,
        );

        // Choose a venue: the selected value label shows the locale's names.
        await _tap(tester, find.text('City Club · Court 2'));
        await _tap(tester, find.text(l.composer_confirm));
        expect(_pillState(tester, 'City Club · Court 2'), GamePillState.chosen);
      });
    }
  });
}
