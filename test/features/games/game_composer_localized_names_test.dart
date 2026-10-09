import 'dart:convert';

import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_parts.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/render_mode.dart';

/// KAN-484: in Arabic the Create game screen shows the Arabic format, venue
/// and space names (English when name_ar is missing), the duration chips
/// come from the ARB, and nothing named name_ar reaches the server. The
/// database is a fake HTTP client: no network, no live data.
final List<(String, Map<String, dynamic>)> _rpc =
    <(String, Map<String, dynamic>)>[];

const List<Map<String, dynamic>> _sports = <Map<String, dynamic>>[
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
    'name_ar': null,
    'required_players': 2,
    'players_per_side': 1,
  },
  {
    'id': 'v-doubles',
    'variant_key': 'doubles',
    'name_en': 'Doubles',
    'name_ar': 'زوجي',
    'required_players': 4,
    'players_per_side': 2,
  },
];

const List<Map<String, dynamic>> _spaces = <Map<String, dynamic>>[
  {
    'id': 'vs-1',
    'name_en': 'Court 1',
    'name_ar': 'ملعب 1',
    'sport_id': 's-padel',
    'sport_variant_keys': ['doubles'],
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
    'name_ar': null,
    'sport_id': 's-padel',
    'sport_variant_keys': ['doubles'],
    'venue': {
      'id': 'ven-2',
      'name_en': 'Sand Club',
      'name_ar': null,
      'area': 'JLT',
    },
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
  'end_at': '2026-11-02T20:00:00',
  'rules': {'duration_minutes': 90, 'max_players': 4},
  'venue_space_id': 'vs-1',
  'venue_name': 'Padel Pro',
  'venue_space_name': 'Court 1',
  'join_policy': 'open',
  'listing_visibility': 'public',
  'allows_waitlist': false,
  'allow_spectators': false,
  'title': 'Evening padel',
  'min_skill': null,
  'max_skill': null,
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
    _rpc.add((
      path.split('/').last,
      jsonDecode(req.body) as Map<String, dynamic>,
    ));
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

Future<void> _pump(WidgetTester tester, Widget body, Locale locale) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activePersonaProvider.overrideWithValue(PersonaType.player)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
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
                      child: Builder(
                        builder: (context) => DabblerSheet(
                          onClose: () => Navigator.of(context).maybePop(),
                          detent: DabblerSheetDetent.content,
                          contentMaxFraction:
                              DabblerSheet.contentMaxFractionFull,
                          pageBackground: true,
                          showCloseButton: false,
                          titleWidget: const SizedBox.shrink(),
                          child: body,
                        ),
                      ),
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

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

Finder _pill(String label) =>
    find.byWidgetPredicate((w) => w is GameSelectPill && w.label == label);

Finder _inTopSheet(Finder f) =>
    find.descendant(of: find.byType(DabblerSheet).last, matching: f);

Future<void> _pickFormat(
  WidgetTester tester,
  AppLocalizations l,
  String rowText,
) async {
  await _tap(tester, find.text('Padel'));
  await _tap(tester, _pill(l.game_select_format));
  await _tap(tester, _inTopSheet(find.text(rowText)));
  await _tap(tester, find.text(l.composer_confirm));
}

Future<void> _openVenue(WidgetTester tester, AppLocalizations l) =>
    _tap(tester, _pill(l.composer_select));

Future<void> _search(WidgetTester tester, String q) async {
  await tester.enterText(
    _inTopSheet(
      find.descendant(
        of: find.byType(DabblerTextField),
        matching: find.byType(EditableText),
      ),
    ),
    q,
  );
  await _settle(tester, 2);
}

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

  setUp(_rpc.clear);

  testWidgets('duration chips: EN exact text', (tester) async {
    await _pump(tester, const GameComposerScreen(), const Locale('en'));
    expect(find.text('30m'), findsOneWidget);
    expect(find.text('1h'), findsOneWidget);
    expect(find.text('2h'), findsOneWidget);
  });

  testWidgets('duration chips: AR exact text, no English suffix', (
    tester,
  ) async {
    await _pump(tester, const GameComposerScreen(), const Locale('ar'));
    expect(find.text('30 د'), findsOneWidget);
    expect(find.text('1 س'), findsOneWidget);
    expect(find.text('2 س'), findsOneWidget);
    expect(find.text('30m'), findsNothing);
    expect(find.text('1h'), findsNothing);
  });

  for (final (String dir, Locale locale, String chip)
      in <(String, Locale, String)>[
        ('en', const Locale('en'), '1h 30m'),
        ('ar', const Locale('ar'), '1 س 30 د'),
      ]) {
    final l = lookupAppLocalizations(locale);
    final bool ar = dir == 'ar';

    testWidgets('format sheet rows and selected label - $dir', (tester) async {
      await _pump(tester, const GameComposerScreen(), locale);
      await _tap(tester, find.text('Padel'));
      await _tap(tester, _pill(l.game_select_format));
      // Doubles has name_ar; Singles has none and falls back to English.
      expect(_inTopSheet(find.text(ar ? 'زوجي' : 'Doubles')), findsOneWidget);
      expect(_inTopSheet(find.text(ar ? 'Doubles' : 'زوجي')), findsNothing);
      expect(_inTopSheet(find.text('Singles')), findsOneWidget);
      await _tap(tester, _inTopSheet(find.text(ar ? 'زوجي' : 'Doubles')));
      await _tap(tester, find.text(l.composer_confirm));
      expect(_pill(ar ? 'زوجي' : 'Doubles'), findsOneWidget);
    });

    testWidgets('venue sheet rows, fallback and selected label - $dir', (
      tester,
    ) async {
      await _pump(tester, const GameComposerScreen(), locale);
      await _pickFormat(tester, l, ar ? 'زوجي' : 'Doubles');
      await _openVenue(tester, l);
      final String localized = ar ? 'بادل برو · ملعب 1' : 'Padel Pro · Court 1';
      expect(_inTopSheet(find.text(localized)), findsOneWidget);
      expect(_inTopSheet(find.text('Sand Club · Court 2')), findsOneWidget);
      if (ar) {
        expect(_inTopSheet(find.text('Padel Pro · Court 1')), findsNothing);
      }
      await _tap(tester, _inTopSheet(find.text(localized)));
      await _tap(tester, find.text(l.composer_confirm));
      expect(_pill(localized), findsOneWidget);
    });

    testWidgets('venue search by Arabic and by English name - $dir', (
      tester,
    ) async {
      await _pump(tester, const GameComposerScreen(), locale);
      await _pickFormat(tester, l, ar ? 'زوجي' : 'Doubles');
      await _openVenue(tester, l);
      final String localized = ar ? 'بادل برو · ملعب 1' : 'Padel Pro · Court 1';
      for (final String q in <String>['برو', 'ملعب', 'padel pro', 'COURT 1']) {
        await _search(tester, q);
        expect(_inTopSheet(find.text(localized)), findsOneWidget, reason: q);
        expect(
          _inTopSheet(find.text('Sand Club · Court 2')),
          findsNothing,
          reason: q,
        );
      }
      await _search(tester, 'sand');
      expect(_inTopSheet(find.text('Sand Club · Court 2')), findsOneWidget);
      expect(_inTopSheet(find.text(localized)), findsNothing);
    });

    testWidgets('edit mode shows localized names and the 90 min chip - $dir', (
      tester,
    ) async {
      await _pump(tester, const GameComposerScreen(editGameId: 'g-1'), locale);
      expect(_pill(ar ? 'زوجي' : 'Doubles'), findsOneWidget);
      expect(
        _pill(ar ? 'بادل برو · ملعب 1' : 'Padel Pro · Court 1'),
        findsOneWidget,
      );
      expect(find.text(chip), findsOneWidget);
      expect(chip, l.game_duration_chip_hours_minutes(1, 30));
    });
  }

  testWidgets('payload: same ids, nothing named name_ar is sent (ar)', (
    tester,
  ) async {
    const Locale locale = Locale('ar');
    final l = lookupAppLocalizations(locale);
    await _pump(tester, const GameComposerScreen(), locale);
    await _pickFormat(tester, l, 'زوجي');
    await _openVenue(tester, l);
    await _tap(tester, _inTopSheet(find.text('بادل برو · ملعب 1')));
    await _tap(tester, find.text(l.composer_confirm));
    await _tap(tester, _pill(l.game_date));
    await _pickTomorrow(tester);
    await _tap(tester, find.text(l.composer_continue_time));
    await _tap(tester, find.text(l.composer_confirm));
    await tester.enterText(
      find.descendant(
        of: find.byType(GamePriceField),
        matching: find.byType(EditableText),
      ),
      '35',
    );
    await _settle(tester, 2);
    await _tap(
      tester,
      find.byKey(const ValueKey<String>('game-composer-submit')),
    );
    final calls = _rpc.where((c) => c.$1 == 'rpc_create_game').toList();
    expect(calls, hasLength(1));
    final Map<String, dynamic> p = calls.single.$2;
    expect(p['p_sport_variant_id'], 'v-doubles');
    expect(p['p_venue_space_id'], 'vs-1');
    final String body = jsonEncode(p);
    expect(body.contains('name_ar'), isFalse);
    expect(body.contains('زوجي'), isFalse);
    expect(body.contains('برو'), isFalse);
    expect(body.contains('ملعب'), isFalse);
  });
}
