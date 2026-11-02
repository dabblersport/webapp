// KAN-759: the real composer submit path sends the launch event game_created
// (KAN-699 / KAN-703) once, with the uuid rpc_create_game returned, and never
// on a failed create or an edit. The database is a fake HTTP client and the
// analytics sink is the AnalyticsService.sinkOverride seam: no network, no
// live data.
import 'dart:convert';

import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_parts.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/services/analytics/analytics_service.dart';
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
import '../../support/connectivity_overrides.dart';

/// The uuid the fake rpc_create_game returns, like the real function.
const String _newGameId = '7c9e6679-7425-40de-944b-e07fc1f90ae7';

/// Every RPC the composer made, by function name.
final List<String> _rpcNames = <String>[];

/// Every event that reached the analytics sink.
final List<(String, Map<String, Object?>)> _events =
    <(String, Map<String, Object?>)>[];
bool _fail = false;

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
  'rules': {'duration_minutes': 60, 'max_players': 6},
  'venue_space_id': 'vs-1',
  'venue_name': 'Padel Pro',
  'venue_space_name': 'Court 1',
  'join_policy': 'open',
  'listing_visibility': 'public',
  'allows_waitlist': false,
  'allow_spectators': false,
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
    _rpcNames.add(path.split('/').last);
    if (_fail) {
      return json(<String, Object>{
        'message': 'network down',
        'code': 'P0001',
      }, 400);
    }
    return json(_newGameId);
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

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _pump(WidgetTester tester, Widget body) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const locale = Locale('en');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onlineConnectivity(),
        activePersonaProvider.overrideWithValue(PersonaType.player),
      ],
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
                      child: DabblerSheet(
                        onClose: () => Navigator.of(context).maybePop(),
                        detent: DabblerSheetDetent.content,
                        contentMaxFraction: DabblerSheet.contentMaxFractionFull,
                        pageBackground: true,
                        showCloseButton: false,
                        title: 'Create game',
                        child: body,
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

/// Sport -> format -> venue -> date + time -> price, the create path's choices.
Future<void> _fill(WidgetTester tester, AppLocalizations l) async {
  await _tap(tester, find.text('Padel'));
  await _tap(tester, find.text(l.game_select_format));
  await _tap(tester, find.text('Doubles'));
  await _tap(tester, find.text(l.composer_confirm));
  await _tap(tester, find.text(l.composer_select));
  await _tap(tester, find.text('Padel Pro · Court 1'));
  await _tap(tester, find.text(l.composer_confirm));
  await _tap(tester, find.text(l.game_date));
  final DateTime now = DateTime.now();
  final DateTime day = DateTime(now.year, now.month, now.day + 1);
  if (day.month != now.month) {
    await tester.tap(find.bySemanticsLabel(RegExp('Next')).first);
    await _settle(tester);
  }
  // The grid also shows the adjacent months' days: an early day of this
  // month is the first match, a late one the last.
  final Finder dayCells = find.descendant(
    of: find.byType(DabblerCalendar),
    matching: find.text('${day.day}'),
  );
  await tester.tap(day.day <= 15 ? dayCells.first : dayCells.last);
  await _settle(tester);
  await _tap(tester, find.text(l.composer_continue_time));
  await _tap(tester, find.text(l.composer_confirm));
  await tester.enterText(
    find
        .descendant(
          of: find.byType(GamePriceField),
          matching: find.byType(EditableText),
        )
        .first,
    '35',
  );
  await _settle(tester, 2);
}

final Finder _submit = find.byKey(
  const ValueKey<String>('game-composer-submit'),
);

List<(String, Map<String, Object?>)> _created() =>
    _events.where((e) => e.$1 == 'game_created').toList();

void main() {
  late AppLocalizations l;

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
    l = lookupAppLocalizations(const Locale('en'));
  });

  setUp(() {
    _rpcNames.clear();
    _events.clear();
    _fail = false;
    AnalyticsService.sinkOverride = (name, props) async {
      _events.add((name, props));
    };
  });

  tearDown(AnalyticsService.resetForTest);

  testWidgets('create succeeds: one game_created, game_id is the RPC uuid', (
    tester,
  ) async {
    await _pump(tester, const GameComposerScreen());
    await _fill(tester, l);
    await _tap(tester, _submit);
    expect(_rpcNames, contains(SupabaseConfig.rpcCreateGameFn));
    final created = _created();
    expect(created, hasLength(1));
    expect(created.single.$2['game_id'], _newGameId);
    // No personal data in the event.
    for (final key in ['email', 'phone', 'name', 'username']) {
      expect(created.single.$2.containsKey(key), isFalse, reason: key);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the create RPC fails: no game_created', (tester) async {
    await _pump(tester, const GameComposerScreen());
    await _fill(tester, l);
    _fail = true;
    await _tap(tester, _submit);
    expect(_rpcNames, contains(SupabaseConfig.rpcCreateGameFn));
    expect(_created(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a game (rpc_update_game): no game_created', (
    tester,
  ) async {
    await _pump(tester, const GameComposerScreen(editGameId: 'g-1'));
    await _settle(tester);
    await _tap(tester, _submit);
    expect(_rpcNames, contains(SupabaseConfig.rpcUpdateGameFn));
    expect(_rpcNames, isNot(contains(SupabaseConfig.rpcCreateGameFn)));
    expect(_created(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
