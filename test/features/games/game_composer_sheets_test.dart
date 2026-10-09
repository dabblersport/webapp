import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_parts.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_sheet_page.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_sheets.dart';
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

/// KAN-473: the Create game sub-sheets (format, date, time, venue, skill)
/// mirror the Home Feed design's sheet frames (`Home Feed.dc.html:1063-1128`,
/// the place sheet `:818-870`, the join-policy pills `:1001-1002`), and what
/// each one writes is unchanged. The database is a fake HTTP client: no
/// network, no live data.
///
/// Renders go to `--dart-define=KAN473_SHOTS=<dir>` when set; measurements are
/// printed as `MEAS` lines.
const String _shots = String.fromEnvironment('KAN473_SHOTS');
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
    'id': 'v-singles',
    'variant_key': 'singles',
    'name_en': 'Singles',
    'required_players': 2,
    'players_per_side': 1,
  },
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

// ignore: avoid_print
void _meas(String k, Object v) => print('MEAS $k $v');

String _r(Rect r) =>
    '[x ${r.left.toStringAsFixed(1)} y ${r.top.toStringAsFixed(1)} '
    'w ${r.width.toStringAsFixed(1)} h ${r.height.toStringAsFixed(1)}]';

/// The sheet route on top (the sub-sheet), not the composer's own sheet.
Finder _topSheet() => find.byType(DabblerSheet).last;

DabblerText _textOf(WidgetTester tester, String s) =>
    tester.widget<DabblerText>(
      find
          .ancestor(
            of: find.descendant(of: _topSheet(), matching: find.text(s)).first,
            matching: find.byType(DabblerText),
          )
          .first,
    );

/// Header checks shared by every sub-sheet: 17/22 semibold title, optional
/// 12/16 muted caption, small neutral Cancel, a hairline under the header.
void _expectHeader(
  WidgetTester tester,
  AppLocalizations l,
  String title, {
  String? caption,
  String tag = '',
  bool divider = true,
}) {
  final DabblerSheet sheet = tester.widget(_topSheet());
  expect(sheet.headerDivider, divider, reason: 'header hairline');
  expect(sheet.pageBackground, isTrue);
  expect(sheet.showCloseButton, isFalse);
  final DabblerText t = _textOf(tester, title);
  expect(t.style, DabblerType.headline); // 17/22
  expect(t.weight, DabblerTextWeight.semibold);
  final Rect tr = tester.getRect(
    find.descendant(of: _topSheet(), matching: find.text(title)).first,
  );
  _meas(
    '$tag.title',
    '${_r(tr)} size ${DabblerType.headline.fontSize}/'
        '${(DabblerType.headline.latinLeading).round()}',
  );
  if (caption != null) {
    final DabblerText c = _textOf(tester, caption);
    expect(c.style, DabblerType.caption1); // 12/16
    expect(c.tone, DabblerTextTone.secondary);
    _meas(
      '$tag.caption',
      _r(
        tester.getRect(
          find.descendant(of: _topSheet(), matching: find.text(caption)).first,
        ),
      ),
    );
  }
  final Finder cancel = find.descendant(
    of: _topSheet(),
    matching: find.widgetWithText(DabblerButton, l.composer_cancel),
  );
  expect(cancel, findsOneWidget);
  final DabblerButton b = tester.widget(cancel);
  expect(b.size, DabblerButtonSize.small);
  expect(b.tone, DabblerButtonTone.neutral);
  _meas('$tag.cancel', _r(tester.getRect(cancel)));
  _meas('$tag.sheet', _r(tester.getRect(_topSheet())));
}

/// The 48dp pill foot (the DS composer submit), full sheet width less the
/// gutters.
Rect _cancelRect(WidgetTester tester, AppLocalizations l) => tester.getRect(
  find.descendant(
    of: _topSheet(),
    matching: find.widgetWithText(DabblerButton, l.composer_cancel),
  ),
);

/// KAN-473 C1: a measured gap must match the design within 1dp.
void _expectGap(String tag, double app, double design) {
  _meas('$tag.gap', 'app ${app.toStringAsFixed(1)} design $design');
  expect((app - design).abs(), lessThanOrEqualTo(1), reason: tag);
}

void _expectFoot(WidgetTester tester, String label, String tag) {
  final Finder foot = find.descendant(
    of: _topSheet(),
    matching: find.byWidgetPredicate(
      (w) => w is DabblerComposerSubmit && w.label == label,
    ),
  );
  expect(foot, findsOneWidget);
  final Rect r = tester.getRect(foot);
  expect(r.height, 48);
  expect(r.width, greaterThan(393 - 2 * 21));
  _meas('$tag.foot', _r(r));
}

GameSelectPill _pillOf(WidgetTester tester, String label) =>
    tester.widget<GameSelectPill>(
      find.byWidgetPredicate((w) => w is GameSelectPill && w.label == label),
    );

Future<void> _tapPill(WidgetTester tester, String label) => _tap(
  tester,
  find.byWidgetPredicate((w) => w is GameSelectPill && w.label == label),
);

Future<void> _pickTomorrow(WidgetTester tester) async {
  final DateTime now = DateTime.now();
  final DateTime day = DateTime(now.year, now.month, now.day + 1);
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
}

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

    testWidgets('format sheet: frame, rows, tick, Confirm writes - $dir', (
      tester,
    ) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      await _tap(tester, find.text('Padel'));
      await _tapPill(tester, l.game_select_format);
      expect(tester.takeException(), isNull);
      _expectHeader(tester, l, l.composer_format_title('Padel'), tag: 'format');
      _expectFoot(tester, l.composer_confirm, 'format');
      // Rows: label 15/20, "{n} players" 13/18 muted, hairline under each.
      final Finder rows = find.descendant(
        of: _topSheet(),
        matching: find.byType(GameSheetOptionRow),
      );
      expect(rows, findsNWidgets(2));
      expect(
        find.descendant(of: rows.first, matching: find.byType(DabblerDivider)),
        findsOneWidget,
      );
      expect(find.text(l.composer_players_count(2)), findsOneWidget);
      expect(find.text(l.composer_players_count(4)), findsOneWidget);
      _meas('format.row0', _r(tester.getRect(rows.at(0))));
      _meas('format.row1', _r(tester.getRect(rows.at(1))));
      // Design: Cancel bottom to row 0 is 31, the last row to the pill 30.
      _expectGap(
        'format.cancel-row0',
        tester.getRect(rows.at(0)).top - _cancelRect(tester, l).bottom,
        31,
      );
      _expectGap(
        'format.list-pill',
        tester
                .getRect(
                  find.byWidgetPredicate(
                    (w) =>
                        w is DabblerComposerSubmit &&
                        w.label == l.composer_confirm,
                  ),
                )
                .top -
            tester.getRect(rows.at(1)).bottom,
        30,
      );
      // No tick until picked; then the bold brand tick and brand-ink label.
      expect(
        find.descendant(
          of: _topSheet(),
          matching: find.byWidgetPredicate(
            (w) => w is DabblerIcon && w.name == 'tick-circle',
          ),
        ),
        findsNothing,
      );
      await _tap(tester, find.text('Doubles'));
      final Finder tick = find.descendant(
        of: _topSheet(),
        matching: find.byWidgetPredicate(
          (w) => w is DabblerIcon && w.name == 'tick-circle',
        ),
      );
      expect(tick, findsOneWidget);
      final DabblerIcon ti = tester.widget(tick);
      expect(ti.weight, DabblerIconWeight.bold);
      expect(ti.color, DabblerColors.of(tester.element(tick)).brandPrimary);
      _meas('format.tick', _r(tester.getRect(tick)));
      await _shoot(tester, 'format-selected-$dir-$mode');
      // Nothing is written until Confirm.
      expect(_pillOf(tester, l.game_select_format).state, GamePillState.idle);
      await _tap(tester, find.text(l.composer_confirm));
      expect(find.byType(DabblerSheet), findsOneWidget);
      expect(_pillOf(tester, 'Doubles').state, GamePillState.chosen);
      expect(find.text('${l.game_players_max} 4'), findsOneWidget);
    });

    testWidgets('date then time: two steps, captions, values - $dir', (
      tester,
    ) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      await _tapPill(tester, l.game_date);
      expect(tester.takeException(), isNull);
      _expectHeader(
        tester,
        l,
        l.composer_pick_date,
        caption: l.composer_step_1,
        tag: 'date',
      );
      _expectFoot(tester, l.composer_continue_time, 'date');
      expect(
        find.descendant(
          of: _topSheet(),
          matching: find.byType(DabblerCalendar),
        ),
        findsOneWidget,
      );
      _meas('date.calendar', _r(tester.getRect(find.byType(DabblerCalendar))));
      // Design: the hairline sits 12 under Cancel, the calendar ~24.5 under
      // the hairline: 36 from Cancel.
      _expectGap(
        'date.cancel-calendar',
        tester.getRect(find.byType(DabblerCalendar)).top -
            _cancelRect(tester, l).bottom,
        36,
      );
      // Continue is disabled until a day is picked.
      DabblerComposerSubmit cont() => tester.widget(
        find.byWidgetPredicate(
          (w) =>
              w is DabblerComposerSubmit && w.label == l.composer_continue_time,
        ),
      );
      expect(cont().enabled, isFalse);
      await _pickTomorrow(tester);
      expect(cont().enabled, isTrue);
      await _shoot(tester, 'date-step1-$dir-$mode');
      await _tap(tester, find.text(l.composer_continue_time));
      // Step 2 opens on its own.
      _expectHeader(
        tester,
        l,
        l.composer_pick_time,
        caption: l.composer_step_2,
        tag: 'time-step',
      );
      _expectFoot(tester, l.composer_confirm, 'time-step');
      expect(find.text(l.composer_kickoff_time), findsNothing);
      expect(find.byType(DabblerTimePicker), findsOneWidget);
      _meas('time.picker', _r(tester.getRect(find.byType(DabblerTimePicker))));
      _expectGap(
        'time.cancel-picker',
        tester.getRect(find.byType(DabblerTimePicker)).top -
            _cancelRect(tester, l).bottom,
        36,
      );
      await _shoot(tester, 'time-step2-$dir-$mode');
      await _tap(tester, find.text(l.composer_confirm));
      expect(find.byType(DabblerSheet), findsOneWidget);
      // The main form now shows the date ("Tomorrow") and 6:00 PM, chosen.
      final String time = DabblerTimeFormat.format(
        const TimeOfDay(hour: 18, minute: 0),
      );
      expect(_pillOf(tester, time).state, GamePillState.chosen);
      expect(
        find.byWidgetPredicate(
          (w) => w is GameSelectPill && w.label == l.game_date,
        ),
        findsNothing,
      );
      _meas('main.after-date-time', time);
    });

    testWidgets('time pill alone: Kickoff time, one step - $dir', (
      tester,
    ) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      await _tapPill(tester, l.game_time);
      _expectHeader(
        tester,
        l,
        l.composer_pick_time,
        caption: l.composer_kickoff_time,
        tag: 'time-only',
      );
      expect(find.text(l.composer_step_2), findsNothing);
      _expectFoot(tester, l.composer_confirm, 'time-only');
      await _shoot(tester, 'time-only-$dir-$mode');
      await _tap(tester, find.text(l.composer_confirm));
      expect(find.byType(DabblerSheet), findsOneWidget);
      // No date step follows; no date was written; the time was.
      expect(find.text(l.composer_pick_date), findsNothing);
      expect(_pillOf(tester, l.game_date).state, GamePillState.idle);
      expect(
        _pillOf(
          tester,
          DabblerTimeFormat.format(const TimeOfDay(hour: 18, minute: 0)),
        ).state,
        GamePillState.chosen,
      );
    });

    testWidgets('venue: locked before format, place frame, Confirm - $dir', (
      tester,
    ) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      await _tap(tester, find.text('Padel'));
      expect(_pillOf(tester, l.composer_select).state, GamePillState.locked);
      await _tapPill(tester, l.composer_select);
      expect(find.text(l.game_select_venue), findsNothing);
      expect(find.byType(DabblerSheet), findsOneWidget);
      await _tapPill(tester, l.game_select_format);
      await _tap(tester, find.text('Doubles'));
      await _tap(tester, find.text(l.composer_confirm));
      expect(_pillOf(tester, l.composer_select).state, GamePillState.idle);
      await _tapPill(tester, l.composer_select);
      expect(tester.takeException(), isNull);
      // The place sheet's header has no hairline (`:820`).
      _expectHeader(
        tester,
        l,
        l.game_select_venue,
        tag: 'venue',
        divider: false,
      );
      _expectFoot(tester, l.composer_confirm, 'venue');
      final DabblerSheet sheet = tester.widget(_topSheet());
      expect(sheet.contentMaxFraction, DabblerSheet.contentMaxFractionMedium);
      expect(sheet.hairlineOutside, isTrue);
      // The framed search box: 42dp.
      final Finder search = find.descendant(
        of: _topSheet(),
        matching: find.byType(DabblerTextField),
      );
      expect(search, findsOneWidget);
      _meas('venue.search', _r(tester.getRect(search)));
      final Finder row = find.byKey(
        const ValueKey<String>('game-venue-space-vs-1'),
      );
      _meas('venue.row', _r(tester.getRect(row)));
      // Design: 24 from the search box to the row box (12 + 12).
      _expectGap(
        'venue.search-row',
        tester.getRect(row).top - tester.getRect(search).bottom,
        24,
      );
      await _tap(tester, find.text('Padel Pro · Court 1'));
      expect(tester.widget<GameSheetOptionRow>(row).selected, isTrue);
      await _shoot(tester, 'venue-selected-$dir-$mode');
      await _tap(tester, find.text(l.composer_confirm));
      expect(find.byType(DabblerSheet), findsOneWidget);
      expect(
        _pillOf(tester, 'Padel Pro · Court 1').state,
        GamePillState.chosen,
      );
    });

    testWidgets('skill: three choice pills, Confirm writes (7, 10) - $dir', (
      tester,
    ) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      await _tapPill(tester, l.game_any_level);
      expect(tester.takeException(), isNull);
      _expectHeader(tester, l, l.game_skill_level, tag: 'skill');
      _expectFoot(tester, l.composer_confirm, 'skill');
      final Finder chips = find.descendant(
        of: _topSheet(),
        matching: find.byType(DabblerChip),
      );
      expect(chips, findsNWidgets(3));
      // Styled as the join-policy pills: the same GameOptionPills/DabblerChip
      // small chips.
      for (final DabblerChip c in tester.widgetList<DabblerChip>(chips)) {
        expect(c.size, DabblerChipSize.small);
        expect(c.selected, isFalse);
      }
      _meas('skill.pill0', _r(tester.getRect(chips.at(0))));
      await _tap(tester, find.text(l.listing_skill_advanced).last);
      expect(tester.widget<DabblerChip>(chips.at(2)).selected, isTrue);
      await _shoot(tester, 'skill-selected-$dir-$mode');
      await _tap(tester, find.text(l.composer_confirm));
      expect(find.byType(DabblerSheet), findsOneWidget);
      expect(
        _pillOf(tester, l.listing_skill_advanced).state,
        GamePillState.chosen,
      );
    });

    Finder sheetCancel() => find.descendant(
      of: _topSheet(),
      matching: find.text(l.composer_cancel),
    );

    Finder clearLink() =>
        find.descendant(of: _topSheet(), matching: find.text(l.composer_clear));

    testWidgets('venue header Clear: stored only, clears; Cancel discards - '
        '$dir', (tester) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      await _tap(tester, find.text('Padel'));
      await _tapPill(tester, l.game_select_format);
      await _tap(tester, find.text('Doubles'));
      await _tap(tester, find.text(l.composer_confirm));
      // Nothing stored: no Clear; a picked row then Cancel writes nothing.
      await _tapPill(tester, l.composer_select);
      expect(clearLink(), findsNothing);
      await _tap(tester, find.text('Padel Pro · Court 1'));
      await _tap(tester, sheetCancel());
      expect(find.byType(DabblerSheet), findsOneWidget);
      expect(_pillOf(tester, l.composer_select).state, GamePillState.idle);
      // Stored: Clear shows; Cancel keeps the stored space.
      await _tapPill(tester, l.composer_select);
      await _tap(tester, find.text('Padel Pro · Court 1'));
      await _tap(tester, find.text(l.composer_confirm));
      await _tapPill(tester, 'Padel Pro · Court 1');
      expect(clearLink(), findsOneWidget);
      await _tap(tester, sheetCancel());
      expect(
        _pillOf(tester, 'Padel Pro · Court 1').state,
        GamePillState.chosen,
      );
      // Clear empties the venue (clearVenue) and closes the sheet.
      await _tapPill(tester, 'Padel Pro · Court 1');
      await _tap(tester, clearLink());
      expect(find.byType(DabblerSheet), findsOneWidget);
      expect(_pillOf(tester, l.composer_select).state, GamePillState.idle);
      expect(find.text('Padel Pro · Court 1'), findsNothing);
      // Format and sport are untouched; nothing was sent.
      expect(_pillOf(tester, 'Doubles').state, GamePillState.chosen);
      expect(_rpc.where((c) => c.$1 == 'rpc_create_game'), isEmpty);
    });

    testWidgets('skill header Clear: stored only, clears; Cancel discards - '
        '$dir', (tester) async {
      await _pump(tester, _gameSheet(const GameComposerScreen()), locale);
      await _tapPill(tester, l.game_any_level);
      expect(clearLink(), findsNothing);
      // A pending pill then Cancel writes nothing.
      await _tap(tester, find.text(l.listing_skill_beginner).last);
      await _tap(tester, sheetCancel());
      expect(find.byType(DabblerSheet), findsOneWidget);
      expect(_pillOf(tester, l.game_any_level).state, GamePillState.idle);
      // Store Advanced; reopen: Clear shows; Beginner then Cancel keeps it.
      await _tapPill(tester, l.game_any_level);
      await _tap(tester, find.text(l.listing_skill_advanced).last);
      await _tap(tester, find.text(l.composer_confirm));
      await _tapPill(tester, l.listing_skill_advanced);
      expect(clearLink(), findsOneWidget);
      await _tap(tester, find.text(l.listing_skill_beginner).last);
      await _tap(tester, sheetCancel());
      expect(
        _pillOf(tester, l.listing_skill_advanced).state,
        GamePillState.chosen,
      );
      // Clear empties the level (clearSkill) and closes the sheet.
      await _tapPill(tester, l.listing_skill_advanced);
      await _tap(tester, clearLink());
      expect(find.byType(DabblerSheet), findsOneWidget);
      expect(_pillOf(tester, l.game_any_level).state, GamePillState.idle);
      expect(_rpc.where((c) => c.$1 == 'rpc_create_game'), isEmpty);
    });
  }

  for (final (String key, int min, int max) in <(String, int, int)>[
    ('Beginner', 1, 3),
    ('Intermediate', 4, 6),
    ('Advanced', 7, 10),
  ]) {
    testWidgets(
      'all five sheets write the KAN-472 payload; $key = ($min, $max)',
      (tester) async {
        final l = lookupAppLocalizations(const Locale('en'));
        await _pump(
          tester,
          _gameSheet(const GameComposerScreen()),
          const Locale('en'),
        );
        await _tap(tester, find.text('Padel'));
        await _tapPill(tester, l.game_select_format);
        await _tap(tester, find.text('Doubles'));
        await _tap(tester, find.text(l.composer_confirm));
        await _tapPill(tester, l.composer_select);
        await _tap(tester, find.text('Padel Pro · Court 1'));
        await _tap(tester, find.text(l.composer_confirm));
        await _tapPill(tester, l.game_date);
        await _pickTomorrow(tester);
        await _tap(tester, find.text(l.composer_continue_time));
        await _tap(tester, find.text(l.composer_confirm));
        await _tapPill(tester, l.game_any_level);
        await _tap(tester, find.text(key).last);
        await _tap(tester, find.text(l.composer_confirm));
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
        await _tap(
          tester,
          find.byKey(const ValueKey<String>('game-composer-submit')),
        );
        final DateTime now = DateTime.now();
        final DateTime start = DateTime(now.year, now.month, now.day + 1, 18);
        final calls = _rpc.where((c) => c.$1 == 'rpc_create_game').toList();
        expect(calls, hasLength(1));
        // The KAN-472 baseline payload key for key, plus the skill range.
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
          'p_min_skill': min,
          'p_max_skill': max,
        });
      },
    );
  }
}
