// KAN-935: the edit flow sends the updated_at it read as p_expected_updated_at
// (the KAN-862 P4 rpc_update_game overload), and on the stale refusal
// (errcode 40001, message stale_update) shows the EN/AR copy and reloads the
// current values. The database is a fake HTTP client; no network.
import 'dart:convert';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
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

const String _readFirst = '2026-11-01T10:00:00.123456+00:00';
const String _readAfterOtherEdit = '2026-11-01T10:05:00.654321+00:00';

/// The updated_at v_game_card serves now; flips when the stale save lands.
String _currentUpdatedAt = _readFirst;
bool _staleOnce = false;
int _cardReads = 0;
final List<Map<String, dynamic>> _updates = <Map<String, dynamic>>[];

Map<String, dynamic> _gameRow() => <String, dynamic>{
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
  'venue_space_id': null,
  'join_policy': 'open',
  'listing_visibility': 'public',
  'allows_waitlist': false,
  'allow_spectators': false,
  'title': 'Evening padel',
  'min_skill': null,
  'max_skill': null,
  'capacity': 4,
  'price_aed': 0,
  'updated_at': _currentUpdatedAt,
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
  if (path.endsWith('/rpc/${SupabaseConfig.rpcUpdateGameFn}')) {
    _updates.add(jsonDecode(req.body) as Map<String, dynamic>);
    if (_staleOnce) {
      _staleOnce = false;
      // Another host saved in between: the row moved on.
      _currentUpdatedAt = _readAfterOtherEdit;
      return json(<String, Object>{
        'code': '40001',
        'message': 'stale_update',
        'details':
            'events.updated_at changed since it was read; re-read the game and retry.',
      }, 500);
    }
    return json('g-1');
  }
  if (path.contains('/rpc/')) return json(<Object>[]);
  if (path.endsWith('/sports')) {
    return json(<Map<String, dynamic>>[
      {'id': 's-padel', 'sport_key': 'padel', 'name_en': 'Padel'},
    ]);
  }
  if (path.endsWith('/v_game_card')) {
    _cardReads++;
    return json(_gameRow());
  }
  return json(<Object>[]);
});

Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final Finder _submit = find.byKey(
  const ValueKey<String>('game-composer-submit'),
);

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(_submit);
  await tester.pump();
  await tester.tap(_submit);
  await _settle(tester);
}

Future<void> _pump(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(393, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
                        child: const GameComposerScreen(editGameId: 'g-1'),
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
    _currentUpdatedAt = _readFirst;
    _staleOnce = false;
    _cardReads = 0;
    _updates.clear();
  });

  testWidgets('a save sends the updated_at it read, unchanged', (tester) async {
    await _pump(tester, const Locale('en'));
    await _tapSubmit(tester);
    expect(_updates, hasLength(1));
    expect(_updates.single['p_game_id'], 'g-1');
    expect(_updates.single['p_expected_updated_at'], _readFirst);
    expect(tester.takeException(), isNull);
  });

  for (final code in const <String>['en', 'ar']) {
    testWidgets('stale refusal: $code copy, current values reloaded', (
      tester,
    ) async {
      final l = lookupAppLocalizations(Locale(code));
      await _pump(tester, Locale(code));
      expect(_cardReads, 1);
      _staleOnce = true;

      await _tapSubmit(tester);
      expect(_updates, hasLength(1));
      expect(_updates.single['p_expected_updated_at'], _readFirst);
      // The form re-read the game and says why the save did not land.
      expect(_cardReads, 2);
      expect(find.text(l.game_error_stale_update), findsWidgets);

      // The next save carries the re-read updated_at and goes through.
      await _tapSubmit(tester);
      expect(_updates, hasLength(2));
      expect(_updates.last['p_expected_updated_at'], _readAfterOtherEdit);
      expect(tester.takeException(), isNull);
    });
  }
}
