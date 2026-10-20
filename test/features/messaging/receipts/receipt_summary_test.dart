import 'package:dabbler/features/messaging/domain/receipt_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('level follows the watermarks: sent < delivered < seen', () {
    ReceiptLevel at(int seq) =>
        receiptLevelFor(seq: seq, deliveredSeq: 5, seenSeq: 3);
    expect(at(3), ReceiptLevel.seen);
    expect(at(4), ReceiptLevel.delivered);
    expect(at(5), ReceiptLevel.delivered);
    expect(at(6), ReceiptLevel.sent);
  });

  test('group counts pick seen, then delivered, then sent', () {
    expect(
      const ReceiptCounts(seen: 4, delivered: 7, total: 9).level,
      ReceiptLevel.seen,
    );
    expect(
      const ReceiptCounts(delivered: 7, total: 9).level,
      ReceiptLevel.delivered,
    );
    expect(const ReceiptCounts(total: 9).level, ReceiptLevel.sent);
    expect(const ReceiptCounts(seen: 9, total: 9).seenByEveryone, isTrue);
    expect(const ReceiptCounts(seen: 4, total: 9).seenByEveryone, isFalse);
    expect(const ReceiptCounts().seenByEveryone, isFalse);
  });
}
