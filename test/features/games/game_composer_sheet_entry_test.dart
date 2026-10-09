import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_composer_screen.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_parts.dart';
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

/// KAN-475: Create game opens as a sheet from every entry point, presented
/// exactly as Create meet-up is (`showMeetupComposerSheet`): the DS sheet on the
/// page colour, content-sized up to 94% over the scrim, a scrim tap closing it.
/// Edit-by-gameId works on the same sheet with sport and format locked. The
/// database is a fake HTTP client. Renders: `--dart-define=KAN475_SHOTS=<dir>`.
const String _shots = String.fromEnvironment('KAN475_SHOTS');
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

const Map<String, dynamic> _gameRow = <String, dynamic>{
  'id': 'g-1',
  'sport_id': 's-padel',
  'sport_name_en': 'Padel',
  'sport_variant_id': 'v-doubles',
  'variant_key': 'doubles',
  'variant_name_en': 'Doubles',
  'required_players': 4,
  'start_at': '2026-11-02T18:30:00',
  'end_at': '2026-11-02T19:30:00',
  'rules': {'duration_minutes': 60, 'notes': 'Bring water', 'max_players': 6},
  'venue_space_id': 'vs-1',
  'venue_name': 'Padel Pro',
  'venue_space_name': 'Court 1',
  'join_policy': 'open',
  'listing_visibility': 'public',
  'allows_waitlist': false,
  'allow_spectators': true,
  'title': 'Evening padel',
  'min_skill': 4,
  'max_skill': 6,
  'capacity': 4,
  'price_aed': 50,
};

const List<Map<String, dynamic>> _sports = <Map<String, dynamic>>[
  {
    'id': 's-football',
    'sport_key': 'football',
    'name_en': 'Football',
    'name_ar': 'كرة القدم',
    'emoji': '⚽',
    'color_code': null,
  },
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
    'required_players': 4,
    'players_per_side': 2,
  },
];

const List<Map<String, dynamic>> _spaces = <Map<String, dynamic>>[
  {
    'id': 'vs-1',
    'name_en': 'Court 1',
    'sport_id': 's-padel',
    'sport_variant_keys': ['doubles'],
    'venue': {'id': 'ven-1', 'name_en': 'Padel Pro', 'area': 'Marina'},
  },
];

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
  if (path.endsWith('/sports')) return json(_sports);
  if (path.endsWith('/sport_variants')) return json(_variants);
  if (path.endsWith('/v_game_card')) return json(_gameRow);
  if (path.endsWith('/venue_spaces')) {
    return json(_spaces);
  }
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

/// Two openers: Create game (`showGameComposerSheet`), Edit game by id, and
/// Create meet-up for the comparison.
Widget _openers(List<bool?> results) => Builder(
  builder: (context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: DabblerSpacing.space4,
    children: <Widget>[
      DabblerButton(
        label: 'open-create',
        onPressed: () async =>
            results.add(await showGameComposerSheet(context)),
      ),
      DabblerButton(
        label: 'open-edit',
        onPressed: () async => results.add(
          await showGameComposerSheet(context, editGameId: 'g-1'),
        ),
      ),
      DabblerButton(
        label: 'open-meetup',
        onPressed: () => showMeetupComposerSheet(context),
      ),
    ],
  ),
);

DabblerSheet _sheetProps(WidgetTester tester) =>
    tester.widget<DabblerSheet>(find.byType(DabblerSheet).last);

GameSelectPill _pillOf(WidgetTester tester, String label) =>
    tester.widget<GameSelectPill>(
      find.byWidgetPredicate((w) => w is GameSelectPill && w.label == label),
    );

void main() {
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

  final String mode = _dark ? 'dark' : 'light';

  for (final (String dir, Locale locale) in <(String, Locale)>[
    ('en', const Locale('en')),
    ('ar', const Locale('ar')),
  ]) {
    final l = lookupAppLocalizations(locale);

    testWidgets(
      'Create game sheet is presented exactly as Create meetup - $dir',
      (tester) async {
        final results = <bool?>[];
        await _pump(tester, _openers(results), locale);
        await _tap(tester, find.text('open-create'));
        expect(find.text(l.game_create), findsWidgets);
        expect(find.byType(GameComposerScreen), findsOneWidget);
        final DabblerSheet game = _sheetProps(tester);
        await _shoot(tester, 'create-sheet-$dir-$mode');

        // A scrim tap dismisses it.
        await tester.tapAt(const Offset(196, 20));
        await _settle(tester);
        expect(find.byType(GameComposerScreen), findsNothing);
        expect(results, <bool?>[null]);

        await _tap(tester, find.text('open-meetup'));
        final DabblerSheet meetup = _sheetProps(tester);
        expect(game.detent, meetup.detent);
        expect(game.contentMaxFraction, meetup.contentMaxFraction);
        expect(game.contentMaxFraction, DabblerSheet.contentMaxFractionFull);
        expect(game.pageBackground, meetup.pageBackground);
        expect(game.showCloseButton, meetup.showCloseButton);
        expect(game.dismissible, meetup.dismissible);
        expect(game.hairlineOutside, meetup.hairlineOutside);
        expect(game.headerDivider, meetup.headerDivider);
        await _shoot(tester, 'meetup-sheet-$dir-$mode');
      },
    );

    testWidgets('Cancel closes the Create game sheet - $dir', (tester) async {
      final results = <bool?>[];
      await _pump(tester, _openers(results), locale);
      await _tap(tester, find.text('open-create'));
      await _tap(tester, find.text(l.composer_cancel));
      expect(find.byType(GameComposerScreen), findsNothing);
      expect(results, <bool?>[null]);
    });

    testWidgets(
      'edit by game id: Edit title, sport and format locked, saves - $dir',
      (tester) async {
        final results = <bool?>[];
        await _pump(tester, _openers(results), locale);
        await _tap(tester, find.text('open-edit'));
        await _settle(tester);
        expect(find.text(l.game_edit), findsWidgets);
        final DabblerInert inert = tester.widget(
          find.ancestor(
            of: find.byType(DabblerEmojiTile).first,
            matching: find.byType(DabblerInert),
          ),
        );
        expect(inert.inert, isTrue);
        expect(_pillOf(tester, 'Doubles').state, GamePillState.locked);
        await _shoot(tester, 'edit-sheet-$dir-$mode');
        await _tap(
          tester,
          find.byKey(const ValueKey<String>('game-composer-submit')),
        );
        // Saved: the sheet closes with true, so the caller can refresh.
        expect(find.byType(GameComposerScreen), findsNothing);
        expect(results, <bool?>[true]);
      },
    );

    testWidgets(
      'a persona that may not create sees the refusal in the sheet - $dir',
      (tester) async {
        final results = <bool?>[];
        await _pump(
          tester,
          _openers(results),
          locale,
          persona: PersonaType.socialiser,
        );
        await _tap(tester, find.text('open-create'));
        expect(find.text(l.game_err_create_refused), findsOneWidget);
        expect(find.byType(GameComposerScreen), findsNothing);
      },
    );
  }
}
