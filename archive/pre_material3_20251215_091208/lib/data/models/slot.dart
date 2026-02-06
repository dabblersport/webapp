import 'package:dabbler/core/utils/json.dart';

/// A read-only projection row from `space_slot_grid`.
/// Column names vary by deployment; mapping is tolerant.
class Slot {
  final String venueSpaceId;
  final DateTime start;
  final DateTime end;

  /// Whether the venue intends to be open at this time (e.g., hours + no blackout).
  final bool isOpen;

  /// Whether the slot is already booked (server-derived).
  final bool isBooked;

  /// Whether *someone* is holding the slot (server-derived).
  final bool isHeld;

  /// Convenience: true only if open && !booked && !held
  final bool isAvailable;

  /// Optional reference to a hold row if the grid exposes it (not required).
  final String? holdId;

  const Slot({
    required this.venueSpaceId,
    required this.start,
    required this.end,
    required this.isOpen,
    required this.isBooked,
    required this.isHeld,
    required this.isAvailable,
    this.holdId,
  });

  factory Slot.fromMap(Map<String, dynamic> row) {
    final m = asMap(row);
    final startRaw =
        m['start_ts'] ?? m['start_at'] ?? m['start'] ?? m['begin_ts'];
    final endRaw = m['end_ts'] ?? m['end_at'] ?? m['end'] ?? m['finish_ts'];

    final open = asBool(m['is_open']) ?? asBool(m['open']) ?? true;
    final booked = asBool(m['is_booked']) ?? asBool(m['booked']) ?? false;
    final held = asBool(m['is_held']) ?? asBool(m['held']) ?? false;

    final explicitAvail = asBool(m['is_available']) ?? asBool(m['available']);
    final computedAvail = (open == true) && (booked != true) && (held != true);

    return Slot(
      venueSpaceId: (m['venue_space_id'] ?? m['space_id'] ?? '').toString(),
      start:
          asDateTime(startRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      end:
          asDateTime(endRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isOpen: open ?? true,
      isBooked: booked,
      isHeld: held,
      isAvailable: explicitAvail ?? computedAvail,
      holdId: m['hold_id']?.toString(),
    );
  }
}

/// Client model for `space_slot_holds`.
class SlotHold {
  final String id;
  final String venueSpaceId;
  final DateTime start;
  final DateTime end;
  final String createdBy;
  final DateTime? createdAt;
  final String? note;

  const SlotHold({
    required this.id,
    required this.venueSpaceId,
    required this.start,
    required this.end,
    required this.createdBy,
    this.createdAt,
    this.note,
  });

  factory SlotHold.fromMap(Map<String, dynamic> row) {
    final m = asMap(row);
    return SlotHold(
      id: (m['id'] ?? '').toString(),
      venueSpaceId: (m['venue_space_id'] ?? m['space_id'] ?? '').toString(),
      start:
          asDateTime(m['start_ts'] ?? m['start_at'] ?? m['start']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      end:
          asDateTime(m['end_ts'] ?? m['end_at'] ?? m['end']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      createdBy: (m['created_by'] ?? '').toString(),
      createdAt: asDateTime(m['created_at']),
      note: m['note']?.toString(),
    );
  }

  Map<String, dynamic> toInsertMap({required String createdBy}) => {
    // id may be db-generated
    'venue_space_id': venueSpaceId,
    'start_ts': start.toUtc().toIso8601String(),
    'end_ts': end.toUtc().toIso8601String(),
    'created_by': createdBy, // satisfy WITH CHECK on RLS
    if (note != null) 'note': note,
  };

  Map<String, dynamic> toUpdateMap() => {
    'venue_space_id': venueSpaceId,
    'start_ts': start.toUtc().toIso8601String(),
    'end_ts': end.toUtc().toIso8601String(),
    if (note != null) 'note': note,
  };
}
