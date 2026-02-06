import 'package:meta/meta.dart';

@immutable
class Wallet {
  final String? id;
  final String? userId;
  final int availableCents;
  final int pendingCents;
  final String? currency;
  final DateTime? updatedAt;

  const Wallet({
    required this.id,
    required this.userId,
    required this.availableCents,
    required this.pendingCents,
    required this.currency,
    required this.updatedAt,
  });

  factory Wallet.fromMap(Map<String, dynamic> m) {
    int readInt(dynamic v) => (v is num) ? v.toInt() : 0;
    DateTime? dt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return Wallet(
      id: m['id']?.toString(),
      userId: m['user_id']?.toString(),
      availableCents: readInt(m['available_cents'] ?? m['balance_cents']),
      pendingCents: readInt(m['pending_cents']),
      currency: m['currency']?.toString(),
      updatedAt: dt(m['updated_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'available_cents': availableCents,
    'pending_cents': pendingCents,
    'currency': currency,
    'updated_at': updatedAt?.toIso8601String(),
  };
}

@immutable
class WalletLedgerEntry {
  final String? id;
  final String? userId;

  /// Positive = credit, negative = debit.
  final int deltaCents;
  final String? kind; // e.g., "game_fee", "refund", etc.
  final String? reason; // free-text/description
  final String? contextId; // nullable UUID as string
  final DateTime? createdAt;

  const WalletLedgerEntry({
    required this.id,
    required this.userId,
    required this.deltaCents,
    required this.kind,
    required this.reason,
    required this.contextId,
    required this.createdAt,
  });

  factory WalletLedgerEntry.fromMap(Map<String, dynamic> m) {
    int readInt(dynamic v) => (v is num) ? v.toInt() : 0;
    DateTime? dt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    final int delta = readInt(
      m['delta_cents'] ?? m['amount_cents'] ?? m['value_cents'],
    );

    return WalletLedgerEntry(
      id: m['id']?.toString(),
      userId: m['user_id']?.toString(),
      deltaCents: delta,
      kind: m['kind']?.toString() ?? m['type']?.toString(),
      reason: m['reason']?.toString() ?? m['description']?.toString(),
      contextId: m['context_id']?.toString(),
      createdAt: dt(m['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'delta_cents': deltaCents,
    'kind': kind,
    'reason': reason,
    'context_id': contextId,
    'created_at': createdAt?.toIso8601String(),
  };
}
