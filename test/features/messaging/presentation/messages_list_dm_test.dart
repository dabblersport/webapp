import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/dm_failure.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/dm_thread_route.dart';
import 'package:dabbler/features/messaging/presentation/messages_list_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/messages_list_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/dm_reason_text.dart';
import 'package:dabbler/features/messaging/presentation/widgets/messages_list_dm_row.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/render_mode.dart';

// KAN-562: DM rows in the Messages list. Fake repository only; no network.
typedef _Variant = ({String name, Locale locale, double scale});

const List<_Variant> _variants = [
  (name: 'ltr', locale: Locale('en'), scale: 1.0),
  (name: 'rtl', locale: Locale('ar'), scale: 1.0),
  (name: 'ltr-200', locale: Locale('en'), scale: 2.0),
  (name: 'rtl-200', locale: Locale('ar'), scale: 2.0),
];

final _now = DateTime.utc(2026, 10, 15, 12);
final _boundary = GlobalKey();

MyConversation _dm(
  String id,
  Duration ago, {
  String? name,
  String? avatar,
  bool muted = false,
  bool readOnly = false,
}) => MyConversation(
  conversationId: id,
  kind: MyConversationKind.dm,
  state: readOnly ? MyConversationState.readOnly : MyConversationState.send,
  counterpartUserId: 'user-$id',
  counterpartName: name,
  counterpartAvatar: avatar,
  muted: muted,
  lastActivityAt: _now.subtract(ago),
);

MyConversation _game(String id, Duration ago) => MyConversation(
  conversationId: 'c-$id',
  gameId: id,
  title: 'Game $id',
  sport: 'Football',
  startAt: DateTime.utc(2026, 10, 17, 19),
  endAt: DateTime.utc(2026, 10, 17, 21),
  state: MyConversationState.send,
  lastActivityAt: _now.subtract(ago),
);

/// Two game chats and four DMs (normal, muted, blocked/read-only, no name),
/// seeded out of order.
List<MyConversation> _seed() => [
  _game('g-old', const Duration(days: 2)),
  _dm('d-noname', const Duration(hours: 6)),
  _dm(
    'd-normal',
    const Duration(minutes: 3),
    name:
        'Layla Abdelrahman Al-Mansouri the very long display name for '
        'truncation checks',
    avatar: 'ds:layla',
  ),
  _game('g-new', const Duration(minutes: 30)),
  _dm('d-muted', const Duration(hours: 1), name: 'Omar', muted: true),
  _dm(
    'd-blocked',
    const Duration(hours: 3),
    name: 'Sara',
    avatar: 'https://img.example.invalid/sara.png',
    readOnly: true,
  ),
];

const _order = [
  'd-normal',
  'g-new',
  'd-muted',
  'd-blocked',
  'd-noname',
  'g-old',
];

class _Nav {
  String? param;
}

Widget _app(FakeMessagingRepository repo, _Variant v, {_Nav? nav}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (c, s) => const MessagesListScreen()),
      GoRoute(
        path: dmThreadRoutePath,
        name: dmThreadRouteName,
        builder: (c, s) {
          nav?.param = s.pathParameters[messagesListDmRouteParam];
          return const SizedBox(key: ValueKey('thread'));
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
        messaging: true,
        gameChat: true,
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

Future<void> _shot(WidgetTester tester, String name) async {
  final boundary =
      _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;
    final file = File('$kShotsRoot/kan562/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MessagesListScreen)));

MessagesListDmRow _row(WidgetTester tester, String id) =>
    tester.widget<MessagesListDmRow>(
      find.byKey(MessagesListScreen.dmRowKey(id), skipOffstage: false),
    );

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
      testWidgets('populated: mixed order as returned, DM avatar + name', (
        tester,
      ) async {
        final repo = FakeMessagingRepository()..seedMyConversations(_seed());
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        final l10n = _l10n(tester);
        await _shot(tester, 'populated-${v.name}');

        final order = <String>[];
        final list = tester.widget<ListView>(
          find.byKey(MessagesListScreen.listKey),
        );
        expect(list, isNotNull);
        for (final e in tester.allElements) {
          final w = e.widget;
          if (w is MessagesListDmRow) {
            order.add((w.key as ValueKey<String>).value.split('row-').last);
          } else if (w is DabblerConversationRow &&
              w.kind == DabblerConversationKind.game) {
            order.add(w.seed!);
          }
        }
        expect(order, _order);

        final normal = _row(tester, 'd-normal');
        expect(normal.name, startsWith('Layla'));
        expect(normal.avatarSeed, 'layla');
        expect(normal.kindLabel, l10n.messaging_dm_kind_label);
        expect(normal.muted, isFalse);
        expect(normal.readOnlyLabel, isNull);
        expect(normal.timestamp, isNotEmpty);
        if (v.locale.languageCode == 'en') {
          expect(normal.timestamp, '3 minutes ago');
        }
        expect(find.byType(DabblerAvatar), findsWidgets);
        // Name truncates on one line, nothing overflows.
        final nameText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(MessagesListScreen.dmRowKey('d-normal')),
            matching: find.text(normal.name),
          ),
        );
        final ds = tester.widget<DabblerConversationRow>(
          find.descendant(
            of: find.byKey(MessagesListScreen.dmRowKey('d-normal')),
            matching: find.byType(DabblerConversationRow),
          ),
        );
        expect(ds.kind, DabblerConversationKind.player);
        expect(ds.seed, 'layla');
        expect(nameText.maxLines, 1);
        expect(nameText.overflow, TextOverflow.ellipsis);
        // Nothing forbidden on any row.
        expect(find.byType(DabblerTypingIndicator), findsNothing);
        for (final r in tester.widgetList<DabblerConversationRow>(
          find.byType(DabblerConversationRow),
        )) {
          expect(r.unread, 0);
          expect(r.preview, isNull);
          expect(r.sender, isNull);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('muted mark and read-only label', (tester) async {
        final repo = FakeMessagingRepository()..seedMyConversations(_seed());
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        final l10n = _l10n(tester);
        final muted = _row(tester, 'd-muted');
        expect(muted.muted, isTrue);
        expect(muted.composedLabel(), contains(l10n.messaging_dm_muted_label));
        expect(
          find.descendant(
            of: find.byKey(MessagesListScreen.dmRowKey('d-muted')),
            matching: find.byType(DabblerIcon),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(MessagesListScreen.dmRowKey('d-normal')),
            matching: find.byType(DabblerIcon),
          ),
          findsNothing,
        );
        final blocked = _row(tester, 'd-blocked');
        expect(blocked.readOnlyLabel, l10n.messaging_dm_read_only_label);
        expect(find.text(l10n.messaging_dm_read_only_label), findsOneWidget);
        // A photo reference keeps the seed portrait (the DS row has no photo
        // slot yet); the helper still resolves the URL for when it does.
        expect(blocked.avatarSeed, 'user-d-blocked');
        expect(
          messagesListDmAvatar(
            'https://img.example.invalid/sara.png',
            'user-d-blocked',
          ).imageUrl,
          'https://img.example.invalid/sara.png',
        );
        await _shot(tester, 'muted-readonly-${v.name}');
        expect(tester.takeException(), isNull);
      });

      testWidgets('missing name falls back to Dabbler user', (tester) async {
        final repo = FakeMessagingRepository()..seedMyConversations(_seed());
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        final l10n = _l10n(tester);
        final r = _row(tester, 'd-noname');
        expect(r.name, l10n.messaging_dm_fallback_name);
        expect(r.avatarSeed, 'user-d-noname');
        if (v.locale.languageCode == 'en') expect(r.name, 'Dabbler user');
        await _shot(tester, 'fallback-${v.name}');
      });

      testWidgets('loading shows skeleton rows', (tester) async {
        final repo = FakeMessagingRepository()
          ..seedMyConversations(_seed())
          ..myConversationsDelay = const Duration(seconds: 2);
        await tester.pumpWidget(_app(repo, v));
        await tester.pump();
        expect(find.byKey(MessagesListScreen.loadingKey), findsOneWidget);
        expect(find.byType(DabblerSkeleton), findsWidgets);
        await _shot(tester, 'loading-${v.name}');
        await tester.pump(const Duration(seconds: 2));
        await _settle(tester);
        expect(find.byType(MessagesListDmRow), findsWidgets);
      });

      testWidgets('empty mentions games and direct messages', (tester) async {
        await tester.pumpWidget(_app(FakeMessagingRepository(), v));
        await _settle(tester);
        final l10n = _l10n(tester);
        expect(find.text(l10n.messaging_list_empty_dm_title), findsOneWidget);
        expect(find.text(l10n.messaging_list_empty_dm_body), findsOneWidget);
        await _shot(tester, 'empty-${v.name}');
        expect(tester.takeException(), isNull);
      });

      testWidgets('error then Retry loads the DM rows', (tester) async {
        final repo = FakeMessagingRepository()
          ..seedMyConversations(_seed())
          ..failNextMyConversations(MessagingReason.offline);
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        final l10n = _l10n(tester);
        expect(find.byKey(MessagesListScreen.errorKey), findsOneWidget);
        await _shot(tester, 'error-${v.name}');
        await tester.tap(find.text(l10n.messaging_list_error_retry));
        await _settle(tester);
        expect(find.byKey(MessagesListScreen.errorKey), findsNothing);
        expect(find.byType(MessagesListDmRow), findsWidgets);
      });

      testWidgets('tapping a DM row routes with the conversation id', (
        tester,
      ) async {
        final repo = FakeMessagingRepository()..seedMyConversations(_seed());
        final nav = _Nav();
        await tester.pumpWidget(_app(repo, v, nav: nav));
        await _settle(tester);
        await tester.tap(find.byKey(MessagesListScreen.dmRowKey('d-muted')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('thread')), findsOneWidget);
        expect(nav.param, 'd-muted');
      });
    });
  }

  testWidgets('RTL: the avatar leads on the right', (tester) async {
    final repo = FakeMessagingRepository()..seedMyConversations(_seed());
    await tester.pumpWidget(_app(repo, _variants[1]));
    await _settle(tester);
    final row = find.byKey(MessagesListScreen.dmRowKey('d-normal'));
    final avatar = find.descendant(
      of: row,
      matching: find.byType(DabblerAvatar),
    );
    final rowRect = tester.getRect(row);
    final avatarRect = tester.getRect(avatar);
    expect(avatarRect.center.dx, greaterThan(rowRect.center.dx));
  });

  test('avatar reference: ds seed, URL, storage path, missing', () {
    expect(messagesListDmAvatar('ds:abc', 'u1'), (seed: 'abc', imageUrl: null));
    expect(messagesListDmAvatar('https://x.invalid/a.png', 'u1'), (
      seed: 'u1',
      imageUrl: 'https://x.invalid/a.png',
    ));
    expect(
      messagesListDmAvatar(
        'a/b.png',
        'u1',
        resolve: (_) => 'https://s/a/b.png',
      ),
      (seed: 'u1', imageUrl: 'https://s/a/b.png'),
    );
    expect(
      messagesListDmAvatar(
        'a/b.png',
        'u1',
        resolve: (_) => throw StateError('x'),
      ),
      (seed: 'u1', imageUrl: null),
    );
    expect(messagesListDmAvatar(null, 'u1'), (seed: 'u1', imageUrl: null));
  });

  testWidgets('dm_cap_reached has its own localized line', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            l10n = AppLocalizations.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      dmReasonText(l10n, DmCapReachedFailure()),
      l10n.messaging_reason_dm_cap_reached,
    );
    expect(
      dmReasonText(l10n, MessagingFailure(reason: MessagingReason.blocked)),
      l10n.messaging_reason_blocked,
    );
  });
}
