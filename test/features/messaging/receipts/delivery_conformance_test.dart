import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/receipt_summary.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_thread_items.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../support/render_mode.dart';

/// KAN-620: delivery states (design section 11, frames 27-30, 32, 44, 46) and
/// group counts rendered through the design system, English/light and
/// Arabic/dark. The thread rows come from the app's own mapping
/// (`gameChatThreadItems`), so the glyph, ink, opacity and tap targets are
/// what a user sees.
typedef _Variant = ({String name, Locale locale, Brightness brightness});

const List<_Variant> _variants = [
  (name: 'en-light', locale: Locale('en'), brightness: Brightness.light),
  (name: 'ar-dark', locale: Locale('ar'), brightness: Brightness.dark),
];

Message _msg(int seq, {bool own = false}) => Message(
  id: 'id$seq',
  conversationId: 'c',
  seq: seq,
  kind: MessageKind.text,
  body: 'message $seq',
  createdAt: DateTime(2026, 3, 3, 9),
  senderUserId: own ? 'me' : 'them',
  clientKey: own ? 'k$seq' : null,
);

/// An incoming message between own ones, so the DS draws each own row's
/// metadata (it shows it on the last message of a run).
ChatItem _them(int seq) => ChatItem(
  body: 'message $seq',
  state: OutgoingState.sent,
  message: _msg(seq),
);

ChatItem _own(int seq) => ChatItem(
  body: 'message $seq',
  state: OutgoingState.sent,
  message: _msg(seq, own: true),
);

ChatItem _pending(String key, OutgoingState s) =>
    ChatItem(body: 'pending $key', state: s, clientKey: key);

Widget _app(
  _Variant v,
  List<ChatItem> items, {
  bool isDm = false,
  Map<int, ReceiptCounts> receipts = const <int, ReceiptCounts>{},
  void Function(String key)? onRetry,
  void Function(DabblerThreadMessage m)? onReceipts,
}) {
  final l10n = lookupAppLocalizations(v.locale);
  final lang = v.locale.languageCode;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: v.locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: DabblerDesignSystemTheme.withFonts(
      DabblerDesignSystemTheme.withTokens(
        v.brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light(),
      ),
      locale: v.locale,
    ),
    home: Scaffold(
      body: DabblerMessageThread(
        lang: lang,
        context: isDm
            ? DabblerMessageContext.direct
            : DabblerMessageContext.group,
        onReceipts: onReceipts,
        items: gameChatThreadItems(
          items: items,
          l10n: l10n,
          locale: lang,
          now: DateTime(2026, 3, 3, 12),
          onRetry: (k) => onRetry?.call(k),
          isDm: isDm,
          receipts: receipts,
        ),
      ),
    ),
  );
}

List<DabblerThreadMessage> _rows(WidgetTester tester) => tester
    .widget<DabblerMessageThread>(find.byType(DabblerMessageThread))
    .items
    .whereType<DabblerThreadMessage>()
    .toList();

void main() {
  setUpAll(() async {
    await loadRenderFonts();
    await initializeDateFormatting('en');
    await initializeDateFormatting('ar');
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  for (final v in _variants) {
    final l10n = lookupAppLocalizations(v.locale);
    final lang = v.locale.languageCode;

    group('[${v.name}] delivery states (section 11)', () {
      testWidgets('all six states render, in a direct chat', (tester) async {
        await tester.pumpWidget(
          _app(
            v,
            [
              _own(1),
              _them(2),
              _own(3),
              _them(4),
              _own(5),
              _pending('s', OutgoingState.sending),
              _pending('f', OutgoingState.failed),
              _pending('r', OutgoingState.retrying),
            ],
            isDm: true,
            receipts: {
              1: const ReceiptCounts(seen: 1, delivered: 1, total: 1),
              3: const ReceiptCounts(delivered: 1, total: 1),
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final byState = {
          for (final m in _rows(tester))
            if (m.deliveryState != null) m.id ?? '': m.deliveryState!,
        };
        expect(byState['id1'], DabblerDeliveryState.seen);
        expect(byState['id3'], DabblerDeliveryState.delivered);
        expect(byState['id5'], DabblerDeliveryState.sent);
        expect(byState['s'], DabblerDeliveryState.sending);
        expect(byState['f'], DabblerDeliveryState.failed);
        expect(byState['r'], DabblerDeliveryState.retrying);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Sending dims the bubble to 0.7; the others stay opaque', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(v, [_pending('s', OutgoingState.sending)], isDm: true),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final dimmed = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .map((w) => w.opacity);
        expect(dimmed, contains(DabblerMessage.sendingOpacity));

        await tester.pumpWidget(
          _app(v, [_pending('r', OutgoingState.retrying)], isDm: true),
        );
        await tester.pump(const Duration(milliseconds: 300));
        // Retrying is in flight too (clock glyph, same dimmed bubble).
        expect(
          tester
              .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
              .map((w) => w.opacity),
          contains(DabblerMessage.sendingOpacity),
        );

        await tester.pumpWidget(_app(v, [_own(1)], isDm: true));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester
              .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
              .map((w) => w.opacity),
          isNot(contains(DabblerMessage.sendingOpacity)),
        );
      });

      testWidgets('direct: only the newest own message spells the word', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            v,
            [_own(1), _them(2), _own(3)],
            isDm: true,
            receipts: {
              1: const ReceiptCounts(seen: 1, delivered: 1, total: 1),
              3: const ReceiptCounts(seen: 1, delivered: 1, total: 1),
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final rows = _rows(tester);
        expect(rows.firstWhere((m) => m.id == 'id1').showDeliveryLabel, false);
        expect(rows.firstWhere((m) => m.id == 'id3').showDeliveryLabel, true);
      });

      testWidgets('Not sent: Retry is a 45 px target; tapping it retries once '
          'with the same key', (tester) async {
        final retried = <String>[];
        await tester.pumpWidget(
          _app(
            v,
            [_pending('f', OutgoingState.failed)],
            isDm: true,
            onRetry: retried.add,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(l10n.messaging_chat_retry), findsOneWidget);
        final size = tester.getSize(find.byKey(DabblerMessage.retryKey));
        expect(size.height, greaterThanOrEqualTo(45));
        await tester.tap(find.byKey(DabblerMessage.retryKey));
        await tester.pump();
        expect(retried, ['f']);
      });

      testWidgets('Failed -> Retrying -> Sent keeps ONE row for the message', (
        tester,
      ) async {
        Future<void> show(ChatItem item) async {
          await tester.pumpWidget(_app(v, [item], isDm: true));
          await tester.pump(const Duration(milliseconds: 300));
        }

        await show(_pending('k', OutgoingState.failed));
        expect(_rows(tester), hasLength(1));
        expect(_rows(tester).single.deliveryState, DabblerDeliveryState.failed);
        await show(_pending('k', OutgoingState.retrying));
        expect(_rows(tester), hasLength(1));
        expect(
          _rows(tester).single.deliveryState,
          DabblerDeliveryState.retrying,
        );
        // The server accepted it: the same idempotency key, now a message.
        await show(
          ChatItem(
            body: 'pending k',
            state: OutgoingState.sent,
            clientKey: 'k',
            message: _msg(7, own: true),
          ),
        );
        expect(_rows(tester), hasLength(1));
        expect(_rows(tester).single.deliveryState, DabblerDeliveryState.sent);
      });
    });

    group('[${v.name}] group counts (section 11)', () {
      String text(DabblerReceipt r) => r.text(lang);

      testWidgets('each branch of the rule, including 0 of M and N = M', (
        tester,
      ) async {
        const cases = <int, ReceiptCounts>{
          1: ReceiptCounts(seen: 3, delivered: 3, total: 3), // everyone
          3: ReceiptCounts(seen: 1, delivered: 2, total: 3), // seen N of M
          5: ReceiptCounts(delivered: 2, total: 3), // delivered N of M
          7: ReceiptCounts(total: 3), // 0 of M: just Sent
        };
        await tester.pumpWidget(
          _app(v, [
            _own(1),
            _them(2),
            _own(3),
            _them(4),
            _own(5),
            _them(6),
            _own(7),
          ], receipts: cases),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final rows = _rows(tester);
        DabblerReceipt receiptOf(String id) =>
            rows.firstWhere((m) => m.id == id).receipt!;
        expect(
          text(receiptOf('id1')),
          text(const DabblerReceipt(seen: 3, delivered: 3, total: 3)),
        );
        expect(
          text(receiptOf('id3')),
          text(const DabblerReceipt(seen: 1, delivered: 2, total: 3)),
        );
        expect(
          text(receiptOf('id5')),
          text(const DabblerReceipt(delivered: 2, total: 3)),
        );
        expect(text(receiptOf('id7')), text(const DabblerReceipt(total: 3)));
        // All four are on screen, the four texts are four different lines.
        expect({
          for (final id in ['id1', 'id3', 'id5', 'id7']) text(receiptOf(id)),
        }, hasLength(4));
        if (lang == 'en') {
          expect(text(receiptOf('id1')), 'Seen by everyone');
          expect(text(receiptOf('id3')), 'Seen by 1 of 3');
          expect(text(receiptOf('id5')), 'Delivered to 2 of 3');
          expect(text(receiptOf('id7')), 'Sent');
        }
        // Others' messages never carry a count.
        expect(
          rows.where((m) => m.direction == DabblerMessageDirection.incoming),
          everyElement(
            isA<DabblerThreadMessage>().having(
              (m) => m.receipt,
              'receipt',
              isNull,
            ),
          ),
        );
      });

      testWidgets('the count is a 45 px button that opens the drawer', (
        tester,
      ) async {
        final opened = <String?>[];
        await tester.pumpWidget(
          _app(
            v,
            [_own(1)],
            receipts: {1: const ReceiptCounts(seen: 1, delivered: 2, total: 3)},
            onReceipts: (m) => opened.add(m.id),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final size = tester.getSize(find.byKey(DabblerMessage.receiptsKey));
        expect(size.height, greaterThanOrEqualTo(45));
        await tester.tap(find.byKey(DabblerMessage.receiptsKey));
        await tester.pump();
        expect(opened, ['id1']);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Sending, Retrying and Not sent behave as in a direct chat', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(v, [
            _pending('s', OutgoingState.sending),
            _pending('f', OutgoingState.failed),
            _pending('r', OutgoingState.retrying),
          ]),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final rows = _rows(tester);
        expect(rows.map((m) => m.deliveryState), [
          DabblerDeliveryState.sending,
          DabblerDeliveryState.failed,
          DabblerDeliveryState.retrying,
        ]);
        expect(rows.every((m) => m.receipt == null), isTrue);
      });
    });
  }

  testWidgets('reduced motion: the Sending dim does not animate', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      _app(_variants.first, [_pending('s', OutgoingState.sending)], isDm: true),
    );
    await tester.pump();
    final opacity = tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .firstWhere((w) => w.opacity == DabblerMessage.sendingOpacity);
    expect(opacity.duration, Duration.zero);
  });
}
