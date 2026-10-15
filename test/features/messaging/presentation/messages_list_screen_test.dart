import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/game_chat_route.dart';
import 'package:dabbler/features/messaging/presentation/messages_list_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/messages_list_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_access_state.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/render_mode.dart';

typedef _Variant = ({String name, Locale locale, double scale});

const List<_Variant> _variants = [
  (name: 'ltr', locale: Locale('en'), scale: 1.0),
  (name: 'rtl', locale: Locale('ar'), scale: 1.0),
  (name: 'ltr-200', locale: Locale('en'), scale: 2.0),
  (name: 'rtl-200', locale: Locale('ar'), scale: 2.0),
];

final _now = DateTime.utc(2026, 10, 15, 12);
final _boundary = GlobalKey();

/// Five chats, deliberately seeded out of order; the fake returns them newest
/// activity first.
List<MyConversation> _seed() => [
  MyConversation(
    conversationId: 'c-old',
    gameId: 'g-old',
    title: 'Sunday tennis doubles',
    sport: 'Tennis',
    startAt: DateTime.utc(2026, 10, 12, 16),
    endAt: DateTime.utc(2026, 10, 12, 18),
    state: MyConversationState.left,
    lastActivityAt: _now.subtract(const Duration(days: 3)),
  ),
  MyConversation(
    conversationId: 'c-new',
    gameId: 'g-new',
    title:
        'Friday night football at the marina sports complex, '
        'bring both shirts and water please',
    sport: 'Football',
    startAt: DateTime.utc(2026, 10, 17, 19),
    endAt: DateTime.utc(2026, 10, 17, 21),
    state: MyConversationState.send,
    lastActivityAt: _now.subtract(const Duration(minutes: 5)),
  ),
  MyConversation(
    conversationId: 'c-ro',
    gameId: 'g-ro',
    title: 'Padel league',
    sport: 'Padel',
    startAt: DateTime.utc(2026, 10, 14, 18),
    endAt: DateTime.utc(2026, 10, 14, 19, 30),
    state: MyConversationState.readOnly,
    lastActivityAt: _now.subtract(const Duration(hours: 2)),
  ),
  MyConversation(
    conversationId: 'c-notitle',
    gameId: 'g-notitle',
    sport: 'Basketball',
    startAt: DateTime.utc(2026, 10, 18, 10),
    endAt: DateTime.utc(2026, 10, 18, 11),
    state: MyConversationState.send,
    lastActivityAt: _now.subtract(const Duration(hours: 5)),
  ),
  MyConversation(
    conversationId: 'c-unknown',
    gameId: 'g-unknown',
    title: '  ',
    state: MyConversationState.send,
    lastActivityAt: _now.subtract(const Duration(days: 1)),
  ),
];

const _expectedOrder = ['g-new', 'g-ro', 'g-notitle', 'g-unknown', 'g-old'];

class _Nav {
  String? gameId;
  Object? extra;
}

Widget _app(
  FakeMessagingRepository repo,
  _Variant v, {
  _Nav? nav,
  bool enabled = true,
  bool viaRoute = false,
}) {
  final router = GoRouter(
    initialLocation: viaRoute ? messagesListRoutePath : '/',
    routes: [
      GoRoute(path: '/', builder: (c, s) => const MessagesListScreen()),
      messagesListRoute(),
      GoRoute(
        path: gameChatRoutePath,
        name: gameChatRouteName,
        builder: (c, s) {
          nav?.gameId = s.pathParameters['gameId'];
          nav?.extra = s.extra;
          return const SizedBox(key: ValueKey('chat'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      fakeMessagingRepositoryProvider.overrideWithValue(repo),
      messagingClockProvider.overrideWithValue(() => _now),
      messagesListFlagsProvider.overrideWithValue((
        messaging: enabled,
        gameChat: enabled,
      )),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: v.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withFonts(
        DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        locale: v.locale,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(v.scale)),
        child: RepaintBoundary(key: _boundary, child: child),
      ),
      routerConfig: router,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Writes a PNG of the screen under SHOTS_ROOT/kan549 (best effort).
Future<void> _shot(WidgetTester tester, String name) async {
  final boundary =
      _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;
    final file = File('$kShotsRoot/kan549/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MessagesListScreen)));

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  for (final v in _variants) {
    group('[${v.name}]', () {
      testWidgets('loading shows skeleton rows, then the list', (tester) async {
        final repo = FakeMessagingRepository()
          ..seedMyConversations(_seed())
          ..myConversationsDelay = const Duration(seconds: 2);
        await tester.pumpWidget(_app(repo, v));
        await tester.pump();
        expect(find.byKey(MessagesListScreen.loadingKey), findsOneWidget);
        expect(find.byType(DabblerSkeleton), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await _shot(tester, 'loading-${v.name}');
        await tester.pump(const Duration(seconds: 2));
        await _settle(tester);
        expect(find.byKey(MessagesListScreen.loadingKey), findsNothing);
        expect(find.byKey(MessagesListScreen.listKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('empty shows the empty state copy', (tester) async {
        final repo = FakeMessagingRepository();
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        final l10n = _l10n(tester);
        expect(find.byKey(MessagesListScreen.emptyKey), findsOneWidget);
        // KAN-562 switched the empty state to copy that names games and
        // direct messages (new keys; the KAN-549 keys are unchanged).
        expect(find.text(l10n.messaging_list_empty_dm_title), findsOneWidget);
        expect(find.text(l10n.messaging_list_empty_dm_body), findsOneWidget);
        if (v.locale.languageCode == 'en') {
          expect(
            find.text('Your game chats and direct messages show up here.'),
            findsOneWidget,
          );
        }
        await _shot(tester, 'empty-${v.name}');
        expect(tester.takeException(), isNull);
      });

      testWidgets('error shows Retry, and Retry reloads', (tester) async {
        final repo = FakeMessagingRepository()
          ..seedMyConversations(_seed())
          ..failNextMyConversations(MessagingReason.offline);
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        final l10n = _l10n(tester);
        expect(find.byKey(MessagesListScreen.errorKey), findsOneWidget);
        expect(find.text(l10n.messaging_list_error_title), findsOneWidget);
        await _shot(tester, 'error-${v.name}');
        expect(repo.myConversationsCalls, 1);
        await tester.tap(find.text(l10n.messaging_list_error_retry));
        await _settle(tester);
        expect(repo.myConversationsCalls, 2);
        expect(find.byKey(MessagesListScreen.errorKey), findsNothing);
        expect(find.byKey(MessagesListScreen.listKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('populated rows: content, order, nothing forbidden', (
        tester,
      ) async {
        final repo = FakeMessagingRepository()..seedMyConversations(_seed());
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        final l10n = _l10n(tester);
        final locale = v.locale.languageCode;
        await _shot(tester, 'populated-${v.name}');

        final rows = tester
            .widgetList<DabblerConversationRow>(
              find.byType(DabblerConversationRow, skipOffstage: false),
            )
            .toList();
        expect(rows.map((r) => r.seed).toList(), _expectedOrder);

        final byGame = {for (final r in rows) r.seed!: r};
        final seed = {for (final c in _seed()) c.gameId: c};
        for (final id in _expectedOrder) {
          final r = byGame[id]!;
          final c = seed[id]!;
          expect(r.kind, DabblerConversationKind.game);
          expect(r.kindLabel, messagesListGameTime(c.startAt, locale));
          expect(
            r.timestamp,
            messagesListRelative(c.lastActivityAt, _now, locale),
          );
          expect(r.timestamp, isNotEmpty);
          // Nothing forbidden: no unread, preview, sender, typing, presence.
          expect(r.unread, 0);
          expect(r.preview, isNull);
          expect(r.sender, isNull);
          expect(r.typing, isFalse);
          expect(r.online, isFalse);
          expect(r.muted, isFalse);
        }
        expect(byGame['g-new']!.sport, DabblerSport.football);
        expect(byGame['g-ro']!.sport, DabblerSport.padel);
        expect(byGame['g-unknown']!.sport, isNull);
        expect(
          byGame['g-notitle']!.title,
          l10n.messaging_list_fallback_title('Basketball'),
        );
        expect(
          byGame['g-unknown']!.title,
          l10n.messaging_list_fallback_unknown_sport,
        );
        expect(byGame['g-new']!.state!.label, l10n.messaging_list_state_send);
        expect(
          byGame['g-ro']!.state!.label,
          l10n.messaging_list_state_read_only,
        );
        expect(byGame['g-old']!.state!.label, l10n.messaging_list_state_left);
        // Quiet label: neutral tone, no icon.
        expect(byGame['g-new']!.state!.status, isNull);

        // Visible content of the first row.
        expect(find.text(messagesListTitle(l10n, seed['g-new']!)), findsOne);
        expect(find.text(byGame['g-new']!.kindLabel!), findsOneWidget);
        expect(find.text(byGame['g-new']!.timestamp), findsOneWidget);
        if (locale == 'en') {
          expect(find.text('5 minutes ago'), findsOneWidget);
        }
        expect(find.byType(DabblerBadge), findsWidgets);
        expect(find.byType(DabblerTypingIndicator), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a row tap opens the game chat with id and end time', (
        tester,
      ) async {
        final repo = FakeMessagingRepository()..seedMyConversations(_seed());
        final nav = _Nav();
        await tester.pumpWidget(_app(repo, v, nav: nav));
        await _settle(tester);
        await tester.tap(find.byKey(MessagesListScreen.rowKey('g-ro')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('chat')), findsOneWidget);
        expect(nav.gameId, 'g-ro');
        expect(nav.extra, DateTime.utc(2026, 10, 14, 19, 30));
      });

      testWidgets('flags off: /messaging shows unavailable, fetches nothing', (
        tester,
      ) async {
        final repo = FakeMessagingRepository()..seedMyConversations(_seed());
        await tester.pumpWidget(_app(repo, v, enabled: false, viaRoute: true));
        await _settle(tester);
        expect(find.byKey(GameChatAccessState.unavailableKey), findsOneWidget);
        expect(find.byType(MessagesListScreen), findsNothing);
        expect(repo.myConversationsCalls, 0);
        await _shot(tester, 'unavailable-${v.name}');
      });
    });
  }

  testWidgets('flags on: /messaging shows the list', (tester) async {
    final repo = FakeMessagingRepository()..seedMyConversations(_seed());
    await tester.pumpWidget(_app(repo, _variants.first, viaRoute: true));
    await _settle(tester);
    expect(find.byType(MessagesListScreen), findsOneWidget);
  });

  test('route gate needs both flags', () {
    expect(messagesListEnabled((messaging: true, gameChat: true)), isTrue);
    expect(messagesListEnabled((messaging: true, gameChat: false)), isFalse);
    expect(messagesListEnabled((messaging: false, gameChat: true)), isFalse);
    expect(messagesListEnabled((messaging: false, gameChat: false)), isFalse);
  });

  test('sport mark maps RPC sport names, unknown is null', () {
    expect(messagesListSport('Table Tennis'), DabblerSport.tableTennis);
    expect(messagesListSport(' football '), DabblerSport.football);
    expect(messagesListSport('Curling'), isNull);
    expect(messagesListSport(null), isNull);
    expect(messagesListSport(''), isNull);
  });
}
