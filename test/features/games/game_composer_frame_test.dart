import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/app/app_router.dart' show rootNavigatorKey;
import 'package:dabbler/app/routes/play_places_routes.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_parts.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_sheet_page.dart';
import 'package:dabbler/features/games/presentation/widgets/game_create_gate.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_composer_screen.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
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

/// KAN-472: the Create game composer mirrors the Home Feed design's Create
/// game frame (`Home Feed.dc.html:925-1062`) inside the DS sheet, with the
/// payload, validation and gates unchanged. The database is a fake HTTP
/// client: no network, no live data.
///
/// Renders go to `--dart-define=KAN472_SHOTS=<dir>` when set; the submitted
/// create payload is written to `--dart-define=KAN472_PAYLOAD_OUT=<file>`.
const String _shots = String.fromEnvironment('KAN472_SHOTS');
const String _payloadOut = String.fromEnvironment('KAN472_PAYLOAD_OUT');
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

final List<(String, Map<String, dynamic>)> _rpc =
    <(String, Map<String, dynamic>)>[];
String? _rpcFailure;

const List<Map<String, dynamic>> _sports = <Map<String, dynamic>>[
  {
    'id': 's-cricket',
    'sport_key': 'cricket',
    'name_en': 'Cricket',
    'emoji': '🏏',
    'color_code': null,
  },
  {
    'id': 's-football',
    'sport_key': 'football',
    'name_en': 'Football',
    'emoji': '⚽',
    'color_code': null,
  },
  {
    'id': 's-padel',
    'sport_key': 'padel',
    'name_en': 'Padel',
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
    final String fn = path.split('/').last;
    _rpc.add((fn, jsonDecode(req.body) as Map<String, dynamic>));
    if (_rpcFailure != null) {
      return json(<String, Object>{
        'message': _rpcFailure!,
        'code': 'P0001',
      }, 400);
    }
    return json('g-new');
  }
  if (path.endsWith('/sports')) return json(_sports);
  if (path.endsWith('/sport_variants')) return json(_variants);
  if (path.endsWith('/venue_spaces')) return json(_spaces);
  if (path.endsWith('/v_game_card')) return json(_gameRow);
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

GameSelectPill _pill(WidgetTester tester, String label) =>
    tester.widget<GameSelectPill>(
      find.byWidgetPredicate((w) => w is GameSelectPill && w.label == label),
    );

/// Sport -> format -> venue -> date + time, the create path's choices.
Future<DateTime> _fill(WidgetTester tester, AppLocalizations l) async {
  await _tap(tester, find.text('Padel'));
  await _tap(tester, find.text(l.game_select_format));
  await _tap(tester, find.text('Doubles'));
  await _tap(tester, find.text(l.composer_confirm));
  await _tap(tester, find.text(l.composer_select));
  await _tap(tester, find.text('Padel Pro · Court 1'));
  await _tap(tester, find.text(l.game_date));
  final DateTime now = DateTime.now();
  final DateTime day = DateTime(now.year, now.month, now.day + 1);
  // The calendar opens on the current month; tomorrow in the next month is
  // reached with the month arrow.
  if (day.month != now.month) {
    await tester.tap(find.bySemanticsLabel(RegExp('Next')).first);
    await _settle(tester);
  }
  await tester.tap(
    find
        .descendant(
          of: find.byType(DabblerCalendar),
          matching: find.text('${day.day}'),
        )
        .last,
  );
  await _settle(tester);
  await _tap(tester, find.text(l.composer_continue_time));
  await _tap(tester, find.text(l.composer_confirm));
  return day;
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

  setUp(() {
    _rpc.clear();
    _rpcFailure = null;
  });

  final String mode = _dark ? 'dark' : 'light';

  for (final (String dir, Locale locale) in <(String, Locale)>[
    ('en', const Locale('en')),
    ('ar', const Locale('ar')),
  ]) {
    final l = lookupAppLocalizations(locale);
    final bool rtl = dir == 'ar';

    testWidgets('frame measurements, initial state - $dir', (tester) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'create-initial-$dir-$mode');

      // Sheet: the DS sheet on the page colour, capped at 94%.
      final DabblerSheet sheet = tester.widget(find.byType(DabblerSheet));
      expect(sheet.pageBackground, isTrue);
      expect(sheet.detent, DabblerSheetDetent.content);
      expect(sheet.contentMaxFraction, 0.94);
      expect(sheet.showCloseButton, isFalse);
      // Header: "Create game" display 22/28 + small neutral Cancel.
      final DabblerText title = tester.widget(
        find.descendant(
          of: find.byType(GameComposerSheetTitle),
          matching: find.byType(DabblerText),
        ),
      );
      expect(title.data, l.game_create);
      expect(title.style, DabblerType.title2);
      final DabblerButton cancel = tester.widget(
        find.descendant(
          of: find.byType(GameComposerCancel),
          matching: find.byType(DabblerButton),
        ),
      );
      expect(cancel.size, DabblerButtonSize.small);
      expect(cancel.tone, DabblerButtonTone.neutral);

      // Sport tiles from the database with sports.emoji: 71 measured, 9 apart,
      // 18 from the sheet edge.
      final Finder tiles = find.byType(DabblerEmojiTile);
      expect(tiles, findsNWidgets(3));
      final Rect t0 = tester.getRect(tiles.at(0));
      final Rect t1 = tester.getRect(tiles.at(1));
      expect(t0.size, const Size(71, 71));
      if (rtl) {
        expect(393 - t0.right, 18);
        expect(t0.left - t1.right, 9);
      } else {
        expect(t0.left, 18);
        expect(t1.left - t0.right, 9);
      }
      expect(find.text('🎾'), findsOneWidget);

      // Section label -> tiles: the 12 rhythm; labels 11/13 muted.
      final Finder sportLabel = find.byWidgetPredicate(
        (w) => w is GameSectionLabel && w.label == l.game_sport,
      );
      expect(t0.top - tester.getRect(sportLabel).bottom, 12);
      final Finder formatRow = find.byType(DabblerComposerRow).first;
      expect(tester.getRect(formatRow).top - t0.bottom, 12);

      // Rows: 14 / 0 padding (28 of the height) plus the 1dp hairline, 20dp
      // icon, gap 12.
      final Rect row = tester.getRect(formatRow);
      final Rect inner = tester.getRect(
        find.descendant(of: formatRow, matching: find.byType(Row)).first,
      );
      expect(row.height - inner.height, 28); // the hairline is painted inside
      expect(row.width, 393 - 36);
      final DabblerIcon glyph = tester.widget(
        find
            .descendant(of: formatRow, matching: find.byType(DabblerIcon))
            .first,
      );
      expect(glyph.name, 'grid-2');
      expect(glyph.size, 20);

      // Icons by row, in the design's order.
      final List<String> icons = tester
          .widgetList<DabblerComposerRow>(find.byType(DabblerComposerRow))
          .map((r) => r.icon)
          .toList();
      expect(icons, <String>[
        'grid-2',
        'location',
        'calendar',
        'timer',
        'medal-star',
        'people',
        'people',
        'eye',
      ]);

      // Format: the locked pill (no sheet opens); Venue: disabled until a
      // format is picked; Date and Time: two pills, muted until chosen.
      expect(_pill(tester, l.game_format_locked).state, GamePillState.locked);
      expect(_pill(tester, l.composer_select).state, GamePillState.locked);
      expect(_pill(tester, l.game_date).state, GamePillState.idle);
      expect(_pill(tester, l.game_time).state, GamePillState.idle);
      await tester.tap(find.text(l.game_format_locked));
      await _settle(tester);
      expect(find.text(l.composer_confirm), findsNothing);
      await tester.tap(find.text(l.composer_select));
      await _settle(tester);
      expect(find.text(l.game_select_venue), findsNothing);

      // Skill: "Any level" is the unset default, a down-arrow pill.
      final GameSelectPill skill = _pill(tester, l.game_any_level);
      expect(skill.trailingIcon, 'arrow-circle-down');
      expect(skill.state, GamePillState.idle);

      // Duration 30m/1h/2h, Join policy and Visibility: small option pills.
      expect(find.text('30m'), findsOneWidget);
      expect(find.text('1h'), findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
      for (final String s in <String>[
        l.game_join_open,
        l.game_join_request,
        l.game_join_invite,
        l.game_join_link,
        l.composer_vis_public,
        l.composer_vis_followers,
        l.composer_vis_private,
      ]) {
        final DabblerChip chip = tester.widget(
          find.ancestor(of: find.text(s), matching: find.byType(DabblerChip)),
        );
        expect(chip.size, DabblerChipSize.small);
      }

      // Players: two stepper pills reading "min N" and "max N".
      expect(find.text('${l.game_players_min} 2'), findsOneWidget);
      expect(find.text('${l.game_players_max} 10'), findsOneWidget);
      expect(find.byType(DabblerStepperPill), findsNWidgets(2));

      // Toggles: the DS toggle at 48x28.
      final Finder toggles = find.byType(DabblerToggle);
      expect(toggles, findsNWidgets(2));
      expect(tester.getSize(toggles.first), const Size(48, 28));

      // Price field in the frame's field style, between Players and toggles.
      final Rect price = tester.getRect(find.byType(GamePriceField));
      // The DS text field (radius 24, a recorded deviation), full width.
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('game-price-field')))
            .width,
        393 - 36,
      );
      expect(price.top, greaterThan(tester.getRect(toggles.first).top - 400));
      expect(
        price.bottom,
        lessThan(
          tester
              .getRect(
                find.byWidgetPredicate(
                  (w) => w is DabblerComposerRow && w.icon == 'eye',
                ),
              )
              .top,
        ),
      );

      // Details: 48 title, 96 note.
      final Finder fields = find.byType(DabblerComposerField);
      expect(tester.getSize(fields.at(0)).height, 48);
      expect(tester.getSize(fields.at(1)).height, greaterThanOrEqualTo(96));

      // Create: a 48 pill at the end of the scrolling form, disabled until
      // the required choices are made (canSubmit unchanged).
      final Finder submit = find.byKey(
        const ValueKey<String>('game-composer-submit'),
      );
      expect(tester.getSize(submit).height, 48);
      expect(
        find.ancestor(of: submit, matching: find.byType(Scrollable)),
        findsWidgets,
      );
      expect(tester.widget<DabblerComposerSubmit>(submit).enabled, isFalse);
      expect(tester.widget<DabblerComposerSubmit>(submit).label, l.game_create);
      await tester.ensureVisible(submit);
      await _settle(tester, 2);
      await _shoot(tester, 'create-initial-bottom-$dir-$mode');
      await _tap(tester, submit);
      expect(_rpc, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filled create: pills, steppers, payload - $dir', (
      tester,
    ) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      final DateTime day = await _fill(tester, l);

      expect(_pill(tester, 'Doubles').state, GamePillState.chosen);
      final GameSelectPill venue = _pill(tester, 'Padel Pro · Court 1');
      expect(venue.state, GamePillState.chosen);
      expect(
        find.descendant(
          of: find.byType(GameSelectPill),
          matching: find.text(l.game_date),
        ),
        findsNothing,
      );
      expect(find.text('${l.game_players_min} 4'), findsOneWidget);
      expect(find.text('${l.game_players_max} 4'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(GamePriceField),
          matching: find.byType(EditableText),
        ),
        '35',
      );
      await _tap(tester, find.text(l.game_join_request));
      await _tap(tester, find.byType(DabblerToggle).first);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(DabblerComposerField).first,
              matching: find.byType(EditableText),
            )
            .first,
        'Evening padel',
      );
      await _settle(tester, 2);
      final Finder submit = find.byKey(
        const ValueKey<String>('game-composer-submit'),
      );
      expect(tester.widget<DabblerComposerSubmit>(submit).enabled, isTrue);
      await tester.ensureVisible(find.byType(GameSectionLabel).first);
      await _settle(tester, 2);
      await _shoot(tester, 'create-filled-$dir-$mode');
      await _tap(tester, submit);
      expect(tester.takeException(), isNull);

      final DateTime start = DateTime(day.year, day.month, day.day, 18);
      final calls = _rpc.where((c) => c.$1 == 'rpc_create_game').toList();
      expect(calls, hasLength(1));
      // The pre-KAN-472 payload, key for key (see the baseline note).
      expect(calls.single.$2, <String, dynamic>{
        'p_actor_type': 'player',
        'p_sport_id': 's-padel',
        'p_sport_variant_id': 'v-doubles',
        'p_start_at': start.toIso8601String(),
        'p_end_at': start.add(const Duration(minutes: 60)).toIso8601String(),
        'p_bench_slots': 0,
        'p_listing_visibility': 'public',
        'p_join_policy': 'request',
        'p_allow_spectators': false,
        'p_allows_waitlist': true,
        'p_rules': <String, dynamic>{'duration_minutes': 60},
        'p_title': 'Evening padel',
        'p_venue_space_id': 'vs-1',
        'p_min_players': 4,
        'p_max_players': 4,
        'p_price_aed': 35.0,
      });
      if (_payloadOut.isNotEmpty && dir == 'en') {
        File(_payloadOut).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(calls.single.$2),
        );
      }
    });

    testWidgets('price_required: client and server paths - $dir', (
      tester,
    ) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      await _fill(tester, l);
      final Finder submit = find.byKey(
        const ValueKey<String>('game-composer-submit'),
      );
      // Empty price: validatePrice refuses before any RPC, the field names
      // the rule.
      await _tap(tester, submit);
      expect(_rpc.where((c) => c.$1 == 'rpc_create_game'), isEmpty);
      expect(find.text(l.game_price_required), findsOneWidget);
      await _shoot(tester, 'create-price-required-$dir-$mode');
      // The server's price_required keeps its message.
      await tester.enterText(
        find.descendant(
          of: find.byType(GamePriceField),
          matching: find.byType(EditableText),
        ),
        '0',
      );
      await _settle(tester, 2);
      expect(find.text(l.game_price_required), findsNothing);
      _rpcFailure = 'price_required';
      await _tap(tester, submit);
      expect(_rpc.where((c) => c.$1 == 'rpc_create_game'), hasLength(1));
      expect(find.text('Enter a price — 0 means free.'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('edit mode: same frame, sport and format locked - $dir', (
      tester,
    ) async {
      await _pump(
        tester,
        _gameSheet(const GameComposerScreen(editGameId: 'g-1'), editing: true),
        locale,
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l.game_edit), findsOneWidget);
      final DabblerInert inert = tester.widget(
        find.ancestor(
          of: find.byType(DabblerEmojiTile).first,
          matching: find.byType(DabblerInert),
        ),
      );
      expect(inert.inert, isTrue);
      expect(_pill(tester, 'Doubles').state, GamePillState.locked);
      expect(_pill(tester, 'Padel Pro · Court 1').state, GamePillState.chosen);
      expect(
        _pill(tester, l.listing_skill_intermediate).state,
        GamePillState.chosen,
      );
      expect(find.text('${l.game_players_max} 6'), findsOneWidget);
      await _shoot(tester, 'edit-$dir-$mode');

      final Finder submit = find.byKey(
        const ValueKey<String>('game-composer-submit'),
      );
      expect(
        tester.widget<DabblerComposerSubmit>(submit).label,
        l.game_save_changes,
      );
      await _tap(tester, submit);
      final calls = _rpc.where((c) => c.$1 == 'rpc_update_game').toList();
      expect(calls, hasLength(1));
      expect(calls.single.$2, <String, dynamic>{
        'p_game_id': 'g-1',
        'p_start_at': '2026-11-02T18:30:00.000',
        'p_end_at': '2026-11-02T19:30:00.000',
        'p_listing_visibility': 'public',
        'p_join_policy': 'open',
        'p_allow_spectators': true,
        'p_allows_waitlist': false,
        'p_rules': <String, dynamic>{
          'duration_minutes': 60,
          'notes': 'Bring water',
        },
        'p_title': 'Evening padel',
        'p_venue_space_id': 'vs-1',
        'p_min_skill': 4,
        'p_max_skill': 6,
        'p_max_players': 6,
        'p_price_aed': 50.0,
      });
    });

    testWidgets('gate: a persona that may not create sees the refusal - $dir', (
      tester,
    ) async {
      await _pump(
        tester,
        _gameSheet(const GameCreateGate(child: GameComposerScreen())),
        locale,
        persona: PersonaType.socialiser,
      );
      expect(find.text(l.game_err_create_refused), findsOneWidget);
      expect(find.byType(GameComposerScreen), findsNothing);
    });
  }

  group('routes present the DS sheet, as Create meet-up', () {
    Future<GoRouter> pumpRouter(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: RoutePaths.home,
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.home,
            builder: (context, state) => Builder(
              builder: (context) => ColoredBox(
                key: const Key('home'),
                color: DabblerColors.of(context).bgSecondary,
                child: Center(
                  child: DabblerButton(
                    label: 'meetup',
                    onPressed: () => showMeetupComposerSheet(context),
                  ),
                ),
              ),
            ),
          ),
          createGameRoute,
          createGameBasicInfoRoute,
          editGameRoute,
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activePersonaProvider.overrideWithValue(PersonaType.player),
            meetupSportsProvider.overrideWith(
              (ref) async => const <MeetupSport>[
                MeetupSport(id: 's-run', nameEn: 'Running', emoji: '🏃'),
              ],
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: _theme(const Locale('en')),
            builder: (context, child) => DabblerToastProvider(child: child!),
          ),
        ),
      );
      await _settle(tester);
      return router;
    }

    DabblerSheet sheetOf(WidgetTester tester) =>
        tester.widget<DabblerSheet>(find.byType(DabblerSheet));

    for (final String path in <String>[
      RoutePaths.createGame,
      RoutePaths.createGameBasicInfo,
      '/edit-game/g-1',
    ]) {
      testWidgets('$path opens the composer in the DS sheet', (tester) async {
        final router = await pumpRouter(tester);
        router.push(path);
        await _settle(tester, 12);
        expect(tester.takeException(), isNull);
        expect(find.byType(GameComposerScreen), findsOneWidget);
        final DabblerSheet game = sheetOf(tester);
        // The panel: content-sized, never above 94% of 852.
        final Rect panel = tester.getRect(
          find
              .descendant(
                of: find.byType(DabblerSheet),
                matching: find.byType(GameComposerSheetTitle),
              )
              .first,
        );
        expect(panel.top, greaterThanOrEqualTo(852 * (1 - 0.94) - 1));
        // A scrim tap dismisses it.
        await tester.tapAt(const Offset(196, 8));
        await _settle(tester, 12);
        expect(find.byType(GameComposerScreen), findsNothing);
        expect(find.byKey(const Key('home')), findsOneWidget);

        // Create meet-up's sheet, for the same numbers.
        await tester.tap(find.text('meetup'));
        await _settle(tester, 12);
        final DabblerSheet meetup = sheetOf(tester);
        expect(game.detent, meetup.detent);
        expect(game.contentMaxFraction, meetup.contentMaxFraction);
        expect(game.contentMaxFraction, 0.94);
        expect(game.pageBackground, meetup.pageBackground);
        expect(game.showCloseButton, meetup.showCloseButton);
        expect(game.dismissible, meetup.dismissible);
        expect(game.presentation, meetup.presentation);
        expect(game.hairlineOutside, meetup.hairlineOutside);
        expect(game.headerDivider, meetup.headerDivider);
      });
    }
  });
}
