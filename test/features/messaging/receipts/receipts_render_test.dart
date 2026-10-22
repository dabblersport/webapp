import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/models/message_page.dart';
import 'package:dabbler/features/messaging/data/receipts_transport.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/receipt_summary.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/receipts_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/render_mode.dart';
import '../support/fake_backend.dart';

/// KAN-580 (UI half): receipts rendered with the design system only. A group
/// message shows the DS receipt count and opens the DS Message info drawer; a
/// direct message shows the DS delivery glyph and word; a Worker without
/// receipts leaves every message at Sent. Screenshots go to SHOTS_ROOT/kan580
/// (best effort); run with `--dart-define=RENDER_DARK=1` for dark.
class _Transport implements ReceiptsTransport {
  _Transport({this.counts = const {}, this.people});

  final Map<int, ReceiptCounts> counts;
  final List<RecipientReceipt>? people;
  final List<int> asked = [];

  @override
  Future<bool> ack(String c, ReceiptState s, int seq) async => true;

  @override
  Future<Map<int, ReceiptCounts>> summaries(String c, List<int> seqs) async {
    asked.addAll(seqs);
    return counts;
  }

  @override
  Future<List<RecipientReceipt>?> recipients(String c, int seq) async => people;
}

typedef _Variant = ({String name, Locale locale});

const List<_Variant> _variants = [
  (name: 'ltr', locale: Locale('en')),
  (name: 'rtl', locale: Locale('ar')),
];

final _boundary = GlobalKey();
final _now = DateTime(2026, 3, 3, 20);
const _dark = String.fromEnvironment('RENDER_DARK') == '1';

/// The seeded thread, with the messages at [own] seqs returned as the
/// caller's own (they carry an idempotency key, as the server returns them to
/// their sender). Own messages are kept apart so the DS draws each one's
/// metadata (it shows it on the last message of a run).
class _Repo extends FakeMessagingRepository {
  _Repo(this.own)
    : super(clock: () => DateTime(2026, 3, 3, 9), currentUserId: 'me');

  final Set<int> own;

  @override
  Future<Result<MessagePage, Failure>> listMessages({
    required String conversationId,
    int? cursor,
    MessageDirection direction = MessageDirection.older,
    int? limit,
  }) async {
    final r = await super.listMessages(
      conversationId: conversationId,
      cursor: cursor,
      direction: direction,
      limit: limit,
    );
    if (r is Err) return r;
    final p = r.requireValue;
    return Ok(
      MessagePage(
        messages: [
          for (final m in p.messages)
            own.contains(m.seq)
                ? Message(
                    id: m.id,
                    conversationId: m.conversationId,
                    seq: m.seq,
                    kind: m.kind,
                    body: 'my message ${m.seq}',
                    createdAt: m.createdAt,
                    senderUserId: 'me',
                    clientKey: 'k${m.seq}',
                  )
                : m,
        ],
        hasOlder: p.hasOlder,
        hasNewer: p.hasNewer,
        pageSize: p.pageSize,
        olderCursor: p.olderCursor,
        newerCursor: p.newerCursor,
      ),
    );
  }
}

Widget _app(
  _Repo repo,
  _Transport transport,
  _Variant v, {
  required Widget home,
}) {
  return ProviderScope(
    overrides: [
      fakeMessagingBackend,
      fakeMessagingRepositoryProvider.overrideWithValue(repo),
      gameChatPollIntervalProvider.overrideWithValue(null),
      messagingClockProvider.overrideWithValue(() => _now),
      receiptsTransportProvider.overrideWithValue(transport),
      receiptPersonNameProvider.overrideWithValue(
        (id) async => {'u1': 'Sara', 'u2': 'Omar', 'u3': 'Lina'}[id] ?? '',
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: v.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withFonts(
        DabblerDesignSystemTheme.withTokens(
          _dark ? ThemeData.dark() : ThemeData.light(),
        ),
        locale: v.locale,
      ),
      builder: (context, child) =>
          RepaintBoundary(key: _boundary, child: child),
      home: home,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
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
    final file = File(
      '$kShotsRoot/kan580/$name-${_dark ? 'dark' : 'light'}.png',
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

List<DabblerThreadMessage> _own(WidgetTester tester) => tester
    .widget<DabblerMessageThread>(find.byKey(GameChatScreen.threadKey))
    .items
    .whereType<DabblerThreadMessage>()
    .where((m) => m.direction == DabblerMessageDirection.outgoing)
    .toList();

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
    final lang = v.locale.languageCode;
    group('[${v.name}]', () {
      testWidgets('group: counts on the DS bubble, drawer lists people', (
        tester,
      ) async {
        final repo = _Repo({2, 4, 6, 8})
          ..seedGameConversation('g1', messageCount: 9);
        final transport = _Transport(
          counts: {
            2: const ReceiptCounts(seen: 3, delivered: 3, total: 3),
            4: const ReceiptCounts(seen: 1, delivered: 2, total: 3),
            6: const ReceiptCounts(seen: 0, delivered: 2, total: 3),
            8: const ReceiptCounts(total: 3),
          },
          people: [
            RecipientReceipt(
              userId: 'u1',
              level: ReceiptLevel.seen,
              updatedAt: DateTime(2026, 3, 3, 9, 5),
            ),
            RecipientReceipt(
              userId: 'u2',
              level: ReceiptLevel.delivered,
              updatedAt: DateTime(2026, 3, 3, 9, 2),
            ),
            const RecipientReceipt(userId: 'u3', level: ReceiptLevel.sent),
          ],
        );
        await tester.pumpWidget(
          _app(repo, transport, v, home: const GameChatScreen(gameId: 'g1')),
        );
        await _settle(tester);

        // The Worker was asked for exactly the caller's own seqs.
        expect(transport.asked.toSet(), {2, 4, 6, 8});
        // DS tally text, in the DS's own words.
        for (final r in [
          const DabblerReceipt(seen: 3, delivered: 3, total: 3),
          const DabblerReceipt(seen: 1, delivered: 2, total: 3),
          const DabblerReceipt(delivered: 2, total: 3),
          const DabblerReceipt(total: 3),
        ]) {
          expect(find.text(r.text(lang)), findsWidgets);
        }
        expect(_own(tester).where((m) => m.receipt != null), hasLength(4));
        await _shot(tester, 'group-receipts-${v.name}');

        // Tapping a count opens the DS Message info drawer.
        final l10n = lookupAppLocalizations(v.locale);
        await tester.tap(
          find.text(
            const DabblerReceipt(seen: 1, delivered: 2, total: 3).text(lang),
          ),
        );
        await _settle(tester);
        expect(find.text(l10n.messaging_receipts_title), findsOneWidget);
        expect(find.byType(DabblerReceiptsSheet), findsOneWidget);
        expect(find.text('Sara'), findsOneWidget);
        expect(find.text('Omar'), findsOneWidget);
        expect(find.text('Lina'), findsOneWidget);
        expect(find.text(l10n.messaging_receipts_not_yet_short), findsWidgets);
        await _shot(tester, 'group-drawer-${v.name}');
        expect(tester.takeException(), isNull);
      });

      testWidgets('a Worker without receipts leaves every message at Sent', (
        tester,
      ) async {
        final repo = _Repo({2, 4})..seedGameConversation('g1', messageCount: 5);
        await tester.pumpWidget(
          _app(repo, _Transport(), v, home: const GameChatScreen(gameId: 'g1')),
        );
        await _settle(tester);
        final own = _own(tester);
        expect(own, hasLength(2));
        expect(own.map((m) => m.deliveryState).toSet(), {
          DabblerDeliveryState.sent,
        });
        expect(own.where((m) => m.receipt != null), isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('direct: the newest own message spells Seen', (tester) async {
        final repo = _Repo({2, 4})
          ..seedGameConversation('dm1', messageCount: 5)
          ..seedMyConversations([
            const MyConversation(
              conversationId: 'conv-dm1',
              kind: MyConversationKind.dm,
              state: MyConversationState.send,
              counterpartUserId: 'member-1',
              counterpartName: 'Sara',
            ),
          ]);
        final transport = _Transport(
          counts: {
            2: const ReceiptCounts(seen: 1, delivered: 1, total: 1),
            4: const ReceiptCounts(delivered: 1, total: 1),
          },
        );
        await tester.pumpWidget(
          _app(
            repo,
            transport,
            v,
            home: const GameChatScreen.dm(conversationId: 'conv-dm1'),
          ),
        );
        await _settle(tester);
        final own = _own(tester);
        expect(own.map((m) => m.deliveryState), [
          DabblerDeliveryState.seen,
          DabblerDeliveryState.delivered,
        ]);
        expect(own.map((m) => m.showDeliveryLabel), [false, true]);
        expect(own.every((m) => m.receipt == null), isTrue);
        expect(
          find.text(
            DabblerDeliveryCopy.label(DabblerDeliveryState.delivered, lang),
          ),
          findsOneWidget,
        );
        await _shot(tester, 'dm-receipts-${v.name}');
        expect(tester.takeException(), isNull);
      });
    });
  }
}
