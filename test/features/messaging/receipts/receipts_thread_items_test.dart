import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/receipt_summary.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_thread_items.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// KAN-580: how a chat row becomes a DS delivery state / receipt.
Message _msg(int seq, {String? key}) => Message(
  id: 'id$seq',
  conversationId: 'c',
  seq: seq,
  kind: MessageKind.text,
  body: 'b$seq',
  createdAt: DateTime(2026, 3, 3, 9),
  senderUserId: key == null ? 'them' : 'me',
  clientKey: key,
);

List<DabblerThreadMessage> _map(
  List<ChatItem> items, {
  bool isDm = false,
  Map<int, ReceiptCounts> receipts = const {},
}) => gameChatThreadItems(
  items: items,
  l10n: lookupAppLocalizations(const Locale('en')),
  locale: 'en',
  now: DateTime(2026, 3, 3, 12),
  onRetry: (_) {},
  isDm: isDm,
  receipts: receipts,
).whereType<DabblerThreadMessage>().toList();

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('pending, retrying and failed own sends carry their own state', () {
    final out = _map([
      const ChatItem(body: 'a', state: OutgoingState.sending, clientKey: 'k1'),
      const ChatItem(body: 'b', state: OutgoingState.retrying, clientKey: 'k2'),
      const ChatItem(body: 'c', state: OutgoingState.failed, clientKey: 'k3'),
    ]);
    expect(out.map((m) => m.deliveryState), [
      DabblerDeliveryState.sending,
      DabblerDeliveryState.retrying,
      DabblerDeliveryState.failed,
    ]);
    expect(out.every((m) => m.receipt == null), isTrue);
  });

  test('incoming messages carry no delivery metadata', () {
    final out = _map(
      [ChatItem(body: 'x', state: OutgoingState.sent, message: _msg(1))],
      receipts: {1: const ReceiptCounts(seen: 1, delivered: 1, total: 1)},
    );
    expect(out.single.deliveryState, isNull);
    expect(out.single.receipt, isNull);
  });

  test('group: a sent message carries the tally; none means plain Sent', () {
    final item = ChatItem(
      body: 'x',
      state: OutgoingState.sent,
      message: _msg(4, key: 'k'),
      clientKey: 'k',
    );
    final withCounts = _map(
      [item],
      receipts: {4: const ReceiptCounts(seen: 2, delivered: 3, total: 5)},
    ).single;
    expect(
      withCounts.receipt,
      const DabblerReceipt(seen: 2, delivered: 3, total: 5),
    );
    expect(withCounts.deliveryState, DabblerDeliveryState.seen);
    expect(withCounts.showDeliveryLabel, isFalse);
    final none = _map([item]).single;
    expect(none.receipt, isNull);
    expect(none.deliveryState, DabblerDeliveryState.sent);
  });

  test('direct: state from the counts, only the newest spells the word', () {
    final a = ChatItem(
      body: 'a',
      state: OutgoingState.sent,
      message: _msg(2, key: 'k1'),
      clientKey: 'k1',
    );
    final b = ChatItem(
      body: 'b',
      state: OutgoingState.sent,
      message: _msg(4, key: 'k2'),
      clientKey: 'k2',
    );
    final out = _map(
      [a, b],
      isDm: true,
      receipts: {
        2: const ReceiptCounts(seen: 1, delivered: 1, total: 1),
        4: const ReceiptCounts(delivered: 1, total: 1),
      },
    );
    expect(out.map((m) => m.deliveryState), [
      DabblerDeliveryState.seen,
      DabblerDeliveryState.delivered,
    ]);
    expect(out.map((m) => m.showDeliveryLabel), [false, true]);
    expect(out.every((m) => m.receipt == null), isTrue);
  });

  test('freshIds fades in only incoming messages', () {
    final out = gameChatThreadItems(
      items: [
        ChatItem(body: 'x', state: OutgoingState.sent, message: _msg(1)),
        ChatItem(
          body: 'y',
          state: OutgoingState.sent,
          message: _msg(2, key: 'k'),
          clientKey: 'k',
        ),
      ],
      l10n: lookupAppLocalizations(const Locale('en')),
      locale: 'en',
      now: DateTime(2026, 3, 3, 12),
      onRetry: (_) {},
      freshIds: {'id1', 'id2'},
    ).whereType<DabblerThreadMessage>().toList();
    expect(out.map((m) => m.fresh), [true, false]);
  });
}
