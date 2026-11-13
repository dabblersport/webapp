// KAN-937: the host cancels one game with an optional reason, sent as
// p_reason to rpc_cancel_game(p_game_id, p_reason).
// KAN-939: a link-policy game's share URL carries a minted join token (`lt`),
// the deep link carries it to the detail screen, and the join sends it as
// p_link_token. No network: every call goes to a MockClient.
import 'dart:convert';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/games/data/repositories/game_host_repository.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_host_actions.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/helpers/deep_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';
import '../../support/render_mode.dart';

const String _gameId = 'a2205c27-9c73-4ecf-8847-03763be74679';
const String _token = '5b0c3e5e-1d0a-4c55-9a39-6a0f4f1b2c3d';

String _rpcPath(String fn) => '/rest/v1/rpc/$fn';

/// A [GameHostRepository] on a MockClient; every request lands in [seen].
GameHostRepository _repo(List<http.Request> seen, {bool fail = false}) =>
    GameHostRepository(
      buildTestSupabaseClient((r) async {
        seen.add(r);
        if (fail) {
          return postgrestErrorResponse(message: 'not_host', request: r);
        }
        final body = r.url.path == _rpcPath(SupabaseConfig.rpcMintJoinLinkFn)
            ? jsonEncode(_token)
            : jsonEncode('cancelled');
        return http.Response(
          body,
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );

GameView _game({String policy = 'open', bool cancelled = false}) =>
    GameView.fromJson({
      'id': _gameId,
      'title': 'Sunday football',
      'start_at': '2030-11-08T16:00:00Z',
      'end_at': '2030-11-08T17:00:00Z',
      'capacity': 10,
      'join_policy': policy,
      'is_cancelled': cancelled,
    });

Widget _host(Widget child) => MaterialApp(
  theme: DabblerDesignSystemTheme.withFonts(
    DabblerDesignSystemTheme.withTokens(renderThemeBase()),
    locale: const Locale('en'),
  ),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('KAN-937 cancel', () {
    test('sends p_game_id and the trimmed reason', () async {
      final seen = <http.Request>[];
      final r = await _repo(seen).cancelGame(_gameId, reason: '  Rain  ');
      expect(r.isSuccess, isTrue);
      expect(seen.single.url.path, _rpcPath('rpc_cancel_game'));
      expect(jsonDecode(seen.single.body), {
        'p_game_id': _gameId,
        'p_reason': 'Rain',
      });
    });

    test('a blank reason is sent as null, never omitted', () async {
      final seen = <http.Request>[];
      await _repo(seen).cancelGame(_gameId, reason: '   ');
      expect(jsonDecode(seen.single.body), {
        'p_game_id': _gameId,
        'p_reason': null,
      });
    });

    testWidgets('host taps Cancel game, types a reason, confirms: the RPC gets '
        'it and the screen reloads', (tester) async {
      final seen = <http.Request>[];
      // Built outside fake-async: the client's realtime heartbeat is a timer.
      final repo = (await tester.runAsync(() async => _repo(seen)))!;
      var reloaded = 0;
      final toasts = <String>[];
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) =>
                gameCancelEntry(
                  context,
                  game: _game(),
                  isHost: true,
                  repo: repo,
                  onDone: () async => reloaded++,
                  toast: (m, _) => toasts.add(m),
                ) ??
                const SizedBox.shrink(),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('game-cancel')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey<String>('game-cancel-reason')),
          matching: find.byType(EditableText),
        ),
        'Pitch closed',
      );
      // The dialog's destructive confirm (the button, not the title).
      await tester.tap(find.text('Cancel game').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(jsonDecode(seen.single.body), {
        'p_game_id': _gameId,
        'p_reason': 'Pitch closed',
      });
      expect(reloaded, 1);
      expect(toasts, ['Game cancelled']);
    });

    testWidgets('Keep game sends nothing', (tester) async {
      final seen = <http.Request>[];
      final repo = (await tester.runAsync(() async => _repo(seen)))!;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => gameCancelEntry(
              context,
              game: _game(),
              isHost: true,
              repo: repo,
              onDone: () async {},
              toast: (_, _) {},
            )!,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('game-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep game'));
      await tester.pumpAndSettle();
      expect(seen, isEmpty);
    });

    testWidgets('no entry for a non-host or a cancelled game', (tester) async {
      late BuildContext ctx;
      final repo = (await tester.runAsync(() async => _repo([])))!;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      Widget? entry({required bool host, bool cancelled = false}) =>
          gameCancelEntry(
            ctx,
            game: _game(cancelled: cancelled),
            isHost: host,
            repo: repo,
            onDone: () async {},
            toast: (_, _) {},
          );
      expect(entry(host: false), isNull);
      expect(entry(host: true, cancelled: true), isNull);
      expect(entry(host: true), isNotNull);
    });
  });

  group('KAN-939 share URL', () {
    test('host of a link-policy game mints a token into the URL', () async {
      final seen = <http.Request>[];
      final r = await buildGameShareLink(
        game: _game(policy: 'link'),
        isHost: true,
        repo: _repo(seen),
      );
      final uri = Uri.parse(r.fold((_) => '', (v) => v));
      expect(uri.pathSegments, ['game', _gameId]);
      expect(uri.queryParameters[DeepLinks.linkTokenParam], _token);
      expect(seen.single.url.path, _rpcPath('rpc_mint_join_link'));
      expect(jsonDecode(seen.single.body), {'p_game_id': _gameId});
    });

    test('a non-host re-shares the token they arrived with', () async {
      final seen = <http.Request>[];
      final r = await buildGameShareLink(
        game: _game(policy: 'link'),
        isHost: false,
        repo: _repo(seen),
        arrivedToken: _token,
      );
      expect(r.fold((_) => '', (v) => v), contains('lt=$_token'));
      expect(seen, isEmpty);
    });

    test('an open game shares the plain link and mints nothing', () async {
      final seen = <http.Request>[];
      final r = await buildGameShareLink(
        game: _game(),
        isHost: true,
        repo: _repo(seen),
      );
      expect(r.fold((_) => '', (v) => v), isNot(contains('lt=')));
      expect(seen, isEmpty);
    });

    test('a failed mint is an error, not an unusable link', () async {
      final r = await buildGameShareLink(
        game: _game(policy: 'link'),
        isHost: true,
        repo: _repo([], fail: true),
      );
      expect(r.isSuccess, isFalse);
    });
  });

  group('KAN-939 deep link', () {
    test('the shared URL resolves to the detail route with the token', () {
      final loc = DeepLinks.resolve(
        Uri.parse('https://app.dabbler.pro/game/$_gameId?lt=$_token'),
        malformedFallback: '/home',
      );
      expect(loc, '/sports/games/$_gameId?lt=$_token');
    });

    test('the custom scheme carries it too; sharer and token both ride', () {
      const sp = '0d4a3f86-2f3b-4f0a-9a1e-1b2c3d4e5f60';
      final loc = DeepLinks.resolve(
        Uri.parse('dabbler://app/game/$_gameId?sp=$sp&lt=$_token'),
        malformedFallback: '/home',
      );
      expect(loc, '/sports/games/$_gameId?sp=$sp&lt=$_token');
    });

    test('a token that is not a UUID is dropped', () {
      final loc = DeepLinks.resolve(
        Uri.parse('https://app.dabbler.pro/game/$_gameId?lt=../x'),
        malformedFallback: '/home',
      );
      expect(loc, '/sports/games/$_gameId');
    });

    test('a token is never put on a non-game link', () {
      final link = DeepLinks.link(
        origin: 'https://app.dabbler.pro',
        type: SharedItemType.venue,
        id: _gameId,
        linkToken: _token,
      );
      expect(link, isNot(contains('lt=')));
    });

    /// A controller whose v_game_card read returns no row (the game is hidden
    /// from this viewer) and whose by-link read answers [byLink].
    Future<(GameViewState, List<http.Request>)> loadHidden(
      WidgetTester tester, {
      String? token,
      List<Map<String, dynamic>> byLink = const [],
    }) async {
      final calls = <http.Request>[];
      late GameViewState state;
      await tester.runAsync(() async {
        final client = buildTestSupabaseClient((r) async {
          if (r.url.path == _rpcPath(SupabaseConfig.rpcGameCardByLinkFn)) {
            calls.add(r);
            return jsonListResponse(byLink, request: r);
          }
          return jsonListResponse(const [], request: r);
        });
        final c = GameViewController(
          supabase: client,
          gameId: _gameId,
          currentUserId: 'u2',
        )..linkToken = token;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        calls.clear(); // the constructor's load ran before the token was set
        await c.refresh();
        state = c.state;
        c.dispose();
      });
      return (state, calls);
    }

    testWidgets('hidden from v_game_card + token: the by-link card renders', (
      tester,
    ) async {
      final (state, calls) = await loadHidden(
        tester,
        token: _token,
        byLink: [
          {
            'id': _gameId,
            'title': 'Weekly padel',
            'start_at': '2030-11-08T16:00:00Z',
            'end_at': '2030-11-08T17:00:00Z',
            'join_policy': 'link',
            'listing_visibility': 'private',
          },
        ],
      );
      expect(jsonDecode(calls.single.body), {
        'p_game_id': _gameId,
        'p_link_token': _token,
      });
      expect(state.game?.title, 'Weekly padel');
      expect(state.game?.joinPolicy, 'link');
      expect(state.error, isNull);
    });

    testWidgets('hidden + an invalid token (zero rows): not found', (
      tester,
    ) async {
      final (state, calls) = await loadHidden(tester, token: _token);
      expect(calls, hasLength(1));
      expect(state.game, isNull);
      expect(state.error, isNotNull);
    });

    testWidgets('hidden + no token: the by-link read is never called', (
      tester,
    ) async {
      final (state, calls) = await loadHidden(tester);
      expect(calls, isEmpty);
      expect(state.game, isNull);
      expect(state.error, isNotNull);
    });

    testWidgets('the join sends the arrived token as p_link_token', (
      tester,
    ) async {
      final joins = <http.Request>[];
      await tester.runAsync(() async {
        final client = buildTestSupabaseClient((r) async {
          if (r.url.path == _rpcPath(SupabaseConfig.rpcJoinGameFn)) {
            joins.add(r);
            return jsonListResponse([
              {'result': 'joined'},
            ], request: r);
          }
          if (r.url.path.contains(SupabaseConfig.vGameCardTable)) {
            return jsonObjectResponse({
              'id': _gameId,
              'title': 'Sunday football',
              'start_at': '2030-11-08T16:00:00Z',
              'end_at': '2030-11-08T17:00:00Z',
              'join_policy': 'link',
            }, request: r);
          }
          return jsonListResponse(const [], request: r);
        });
        final c = GameViewController(
          supabase: client,
          gameId: _gameId,
          currentUserId: 'u1',
        )..linkToken = _token;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await c.joinGame();
        c.dispose();
      });
      expect(jsonDecode(joins.single.body), {
        'p_actor_type': 'player',
        'p_game_id': _gameId,
        'p_link_token': _token,
      });
    });
  });
}
