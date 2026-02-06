import 'package:meta/meta.dart';

@immutable
class Payout {
  final String? id;
  final String? userId;
  final int amountCents;
  final String? currency;
  final String? status; // e.g., 'queued','processing','paid','failed'
  final DateTime? createdAt;
  final DateTime? processedAt;

  const Payout({
    required this.id,
    required this.userId,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.processedAt,
  });

  factory Payout.fromMap(Map<String, dynamic> m) {
    int readInt(dynamic v) => (v is num) ? v.toInt() : 0;
    DateTime? dt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return Payout(
      id: m['id']?.toString(),
      userId: m['user_id']?.toString(),
      amountCents: readInt(m['amount_cents']),
      currency: m['currency']?.toString(),
      status: m['status']?.toString(),
      createdAt: dt(m['created_at']),
      processedAt: dt(m['processed_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'amount_cents': amountCents,
    'currency': currency,
    'status': status,
    'created_at': createdAt?.toIso8601String(),
    'processed_at': processedAt?.toIso8601String(),
  };
}
