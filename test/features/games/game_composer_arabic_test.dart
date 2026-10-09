import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
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

/// KAN-474: the Create game form reads every user-facing string from the ARB:
/// design wording, the min / max stepper words (word first), the sport tile
/// label and its screen-reader sentence, the venue sheet text. English is the
/// same words as before; Arabic is Arabic. The database is a fake HTTP client.
/// Renders go to `--dart-define=KAN474_SHOTS=<dir>`.
const String _shots = String.fromEnvironment('KAN474_SHOTS');
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

bool _noSpaces = false;

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
  if (path.endsWith('/venue_spaces')) {
    return json(_noSpaces ? <Object>[] : _spaces);
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

  setUp(() => _noSpaces = false);

  final String mode = _dark ? 'dark' : 'light';

  for (final (String dir, Locale locale) in <(String, Locale)>[
    ('en', const Locale('en')),
    ('ar', const Locale('ar')),
  ]) {
    final l = lookupAppLocalizations(locale);
    final bool ar = dir == 'ar';

    testWidgets('form wording and min / max words come from the ARB - $dir', (
      tester,
    ) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      expect(find.text(l.game_date_time), findsOneWidget);
      expect(find.text(l.game_skill_level), findsOneWidget);
      expect(find.text(l.game_players_sub), findsOneWidget);
      // Word first, then the number, in both languages.
      // Word first, then the number, in both languages (the pill's own label).
      for (final String word in <String>[
        l.game_players_min,
        l.game_players_max,
      ]) {
        final List<String> labels = tester
            .widgetList<Text>(find.textContaining('$word '))
            .map((t) => t.data ?? '')
            .where((d) => RegExp('^${RegExp.escape(word)} \\d+\$').hasMatch(d))
            .toList();
        expect(labels, isNotEmpty, reason: 'pill "$word N"');
      }
      if (ar) {
        expect(find.text('Date & time'), findsNothing);
        expect(find.text('Skill level'), findsNothing);
        expect(find.text('Min and max players'), findsNothing);
      } else {
        // English: the three design wording corrections.
        expect(find.text('Date & time'), findsOneWidget);
        expect(find.text('Skill level'), findsOneWidget);
        expect(find.text('Min and max players'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'form-$dir-$mode');
    });

    testWidgets('sport tiles: label and screen-reader sentence - $dir', (
      tester,
    ) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      final String padel = ar ? 'بادل' : 'Padel';
      final DabblerEmojiTile tile = tester.widget(
        find.widgetWithText(DabblerEmojiTile, padel),
      );
      expect(tile.semanticLabel, l.game_sport_tile_semantic(padel));
      expect(
        tile.semanticLabel,
        ar ? 'الرياضة: بادل، اضغط للاختيار' : 'Sport: Padel, tap to select',
      );
      expect(find.text(ar ? 'Padel' : 'بادل'), findsNothing);
    });

    testWidgets('venue sheet: search placeholder and empty text - $dir', (
      tester,
    ) async {
      _noSpaces = true;
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      await _tap(tester, find.text(ar ? 'بادل' : 'Padel'));
      await _tap(tester, _pill(l.game_select_format));
      await _tap(tester, find.text('Doubles'));
      await _tap(tester, find.text(l.composer_confirm));
      await _tap(tester, _pill(l.composer_select));
      expect(find.text(l.game_venue_none), findsOneWidget);
      expect(
        find.text(
          ar
              ? 'لا توجد ملاعب متاحة لهذه الصيغة'
              : 'No venues available for this format',
        ),
        findsOneWidget,
      );
      await _shoot(tester, 'venue-none-$dir-$mode');
    });

    testWidgets('venue sheet with venues: search placeholder - $dir', (
      tester,
    ) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      await _tap(tester, find.text(ar ? 'بادل' : 'Padel'));
      await _tap(tester, _pill(l.game_select_format));
      await _tap(tester, find.text('Doubles'));
      await _tap(tester, find.text(l.composer_confirm));
      await _tap(tester, _pill(l.composer_select));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DabblerTextField &&
              w.placeholder == l.game_venue_search_placeholder,
        ),
        findsOneWidget,
      );
      await _shoot(tester, 'venue-sheet-$dir-$mode');
    });

    test('failure toast words are the ARB ones - $dir', () {
      expect(
        l.game_create_failed,
        ar ? 'تعذّر إنشاء المباراة' : 'Failed to create game',
      );
      expect(
        l.game_save_failed,
        ar ? 'تعذّر حفظ التغييرات' : 'Failed to save changes',
      );
    });
  }
}
