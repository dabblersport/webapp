// KAN-739: every game composer save is exactly one authorised RPC and never a
// second write to a shared column. The database is a fake HTTP client that
// records every request, so a stray table write (POST/PATCH/PUT/DELETE to a
// table path) would show up here. No network, no live data.
import 'dart:convert';

import 'package:dabbler/core/config/supabase_config.dart';
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

import '../../support/connectivity_overrides.dart';
import '../../support/render_mode.dart';

/// Every request the composer made: (method, path after /rest/v1).
final List<(String, String)> _requests = <(String, String)>[];

/// Bodies of the RPCs, by function name.
final List<(String, Map<String, dynamic>)> _rpcs =
    <(String, Map<String, dynamic>)>[];

bool _fail = false;

/// Support RPCs that are not a save of the game: the daily creation cooldown
/// and analytics. Neither writes a game or event column.
const Set<String> _supportRpcs = <String>{
  'check_and_bump_cooldown',
  SupabaseConfig.rpcTrackEventFn,
};

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
  _requests.add((req.method, path.split('/rest/v1').last));
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
    _rpcs.add((
      path.split('/rpc/').last,
      jsonDecode(req.body) as Map<String, dynamic>,
    ));
    if (_fail) {
      return json(<String, Object>{
        'message': 'network down',
        'code': 'P0001',
      }, 400);
    }
    return json('g-new');
  }
  if (path.endsWith('/sports')) {
    return json(<Map<String, dynamic>>[
      {
        'id': 's-padel',
        'sport_key': 'padel',
        'name_en': 'Padel',
        'emoji': '🎾',
        'color_code': null,
      },
    ]);
  }
  if (path.endsWith('/sport_variants')) {
    return json(<Map<String, dynamic>>[
      {
        'id': 'v-doubles',
        'variant_key': 'doubles',
        'name_en': 'Doubles',
        'required_players': 4,
        'players_per_side': 2,
      },
    ]);
  }
  if (path.endsWith('/venue_spaces')) {
    return json(<Map<String, dynamic>>[
      {
        'id': 'vs-1',
        'name_en': 'Court 1',
        'sport_id': 's-padel',
        'sport_variant_keys': ['doubles'],
        'venue': {
          'id': 'ven-1',
          'name_en': 'Padel Pro',
          'area': 'Marina',
          'geo_location_id': 'geo-1',
          'area_id': 'area-1',
        },
      },
    ]);
  }
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

Future<void> _pump(WidgetTester tester, {String? editGameId}) async {
  tester.view.physicalSize = const Size(393, 1200);
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
                        title: 'Game',
                        child: GameComposerScreen(editGameId: editGameId),
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

/// Sport -> format -> venue -> date + time, then the price.
Future<void> _fill(
  WidgetTester tester,
  AppLocalizations l, {
  required String price,
}) async {
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
    price,
  );
  await _settle(tester, 2);
}

final Finder _submit = find.byKey(
  const ValueKey<String>('game-composer-submit'),
);

/// The saves: RPCs other than the cooldown and analytics support calls.
List<(String, Map<String, dynamic>)> _saves() =>
    _rpcs.where((r) => !_supportRpcs.contains(r.$1)).toList();

/// Any request that could write a table column directly: a non-GET that is not
/// an RPC call. A save must produce none.
List<(String, String)> _tableWrites() => _requests
    .where((r) => r.$1 != 'GET' && !r.$2.startsWith('/rpc/'))
    .toList();

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
    _requests.clear();
    _rpcs.clear();
    _fail = false;
  });

  testWidgets('create is one rpc_create_game and no table write', (
    tester,
  ) async {
    await _pump(tester);
    await _fill(tester, l, price: '35');
    await _tap(tester, _submit);
    final saves = _saves();
    expect(saves, hasLength(1));
    expect(saves.single.$1, SupabaseConfig.rpcCreateGameFn);
    expect(_tableWrites(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly series is one rpc_create_game_series and no table write', (
    tester,
  ) async {
    await _pump(tester);
    await _fill(tester, l, price: '0');
    await _tap(tester, find.text(l.recurring_repeat_label));
    await _tap(tester, find.text(l.recurring_option_weekly));
    await _tap(tester, _submit);
    final saves = _saves();
    expect(saves, hasLength(1));
    expect(saves.single.$1, SupabaseConfig.rpcCreateGameSeriesFn);
    expect(_tableWrites(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit is one rpc_update_game and no second write', (
    tester,
  ) async {
    await _pump(tester, editGameId: 'g-1');
    await _tap(tester, _submit);
    final saves = _saves();
    expect(saves, hasLength(1));
    expect(saves.single.$1, SupabaseConfig.rpcUpdateGameFn);
    expect(saves.single.$2['p_game_id'], 'g-1');
    expect(_tableWrites(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed save sends one RPC, no fallback write, form kept', (
    tester,
  ) async {
    await _pump(tester);
    await _fill(tester, l, price: '35');
    _fail = true;
    await _tap(tester, _submit);
    expect(_saves(), hasLength(1));
    expect(_tableWrites(), isEmpty);
    expect(tester.widget<DabblerComposerSubmit>(_submit).enabled, isTrue);
    expect(tester.takeException(), isNull);
  });
}
