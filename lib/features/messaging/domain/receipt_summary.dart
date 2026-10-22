/// A sent message's state for one recipient (KAN-580): `sent < delivered <
/// seen`.
enum ReceiptLevel { sent, delivered, seen }

/// How many recipients of one of the caller's group messages have it
/// delivered or seen, out of [total] (`msg_receipt_summary`).
class ReceiptCounts {
  const ReceiptCounts({this.seen = 0, this.delivered = 0, this.total = 0});

  /// Recipients who saw it.
  final int seen;

  /// Recipients it reached (seen ones included).
  final int delivered;

  /// Recipients in all.
  final int total;

  /// The compact level a group message shows: seen if anyone saw it,
  /// delivered if it reached anyone, otherwise sent. Mirrors the approved
  /// design's `receiptState`.
  ReceiptLevel get level => seen > 0
      ? ReceiptLevel.seen
      : delivered > 0
      ? ReceiptLevel.delivered
      : ReceiptLevel.sent;

  /// Whether every recipient has seen it.
  bool get seenByEveryone => total > 0 && seen >= total;
}

/// One recipient's level for a message, from the watermarks: seen if
/// `seq <= seenSeq`, else delivered if `seq <= deliveredSeq`, else sent.
ReceiptLevel receiptLevelFor({
  required int seq,
  required int deliveredSeq,
  required int seenSeq,
}) => seq <= seenSeq
    ? ReceiptLevel.seen
    : seq <= deliveredSeq
    ? ReceiptLevel.delivered
    : ReceiptLevel.sent;
