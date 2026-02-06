import 'package:dabbler/core/utils/json.dart';

class VenueSpace {
  final String id;
  final String venueId;
  final String name;
  final bool isActive;
  final int? capacity;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VenueSpace({
    required this.id,
    required this.venueId,
    required this.name,
    required this.isActive,
    this.capacity,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory VenueSpace.fromMap(Map<String, dynamic> row) {
    final m = asMap(row);
    return VenueSpace(
      id: (m['id'] ?? '').toString(),
      venueId: (m['venue_id'] ?? m['venueId'] ?? '').toString(),
      name: (m['name'] ?? m['title'] ?? '').toString(),
      isActive: asBool(m['is_active']) ?? asBool(m['isActive']) ?? false,
      capacity: m['capacity'] == null
          ? null
          : int.tryParse(m['capacity'].toString()),
      description: m['description']?.toString(),
      createdAt: asDateTime(m['created_at']),
      updatedAt: asDateTime(m['updated_at']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'id': id,
    'venue_id': venueId,
    'name': name,
    'is_active': isActive,
    if (capacity != null) 'capacity': capacity,
    if (description != null) 'description': description,
  };

  Map<String, dynamic> toUpdateMap() => {
    'venue_id': venueId,
    'name': name,
    'is_active': isActive,
    'capacity': capacity,
    'description': description,
  };
}

/// One opening-hours row for a specific space (policy: public read).
class OpeningHour {
  final String id;
  final String venueSpaceId;
  final int dayOfWeek; // 0=Mon .. 6=Sun (or match your schema)
  final String startTime; // HH:MM:SS from DB (keep as string for tolerance)
  final String endTime; // HH:MM:SS

  const OpeningHour({
    required this.id,
    required this.venueSpaceId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory OpeningHour.fromMap(Map<String, dynamic> row) {
    final m = asMap(row);
    return OpeningHour(
      id: (m['id'] ?? '').toString(),
      venueSpaceId: (m['venue_space_id'] ?? m['space_id'] ?? '').toString(),
      dayOfWeek:
          int.tryParse((m['day_of_week'] ?? m['dow'] ?? '0').toString()) ?? 0,
      startTime: (m['start_time'] ?? m['opens_at'] ?? '00:00:00').toString(),
      endTime: (m['end_time'] ?? m['closes_at'] ?? '23:59:59').toString(),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'id': id,
    'venue_space_id': venueSpaceId,
    'day_of_week': dayOfWeek,
    'start_time': startTime,
    'end_time': endTime,
  };

  Map<String, dynamic> toUpdateMap() => {
    'venue_space_id': venueSpaceId,
    'day_of_week': dayOfWeek,
    'start_time': startTime,
    'end_time': endTime,
  };
}

/// Price row per space (policy: read only when is_active=true; writes for venue admins/managers).
class SpacePrice {
  final String id;
  final String venueSpaceId;
  final bool isActive;
  final String? label;
  final String currency; // e.g. "USD"
  final num amount; // numeric/decimal from Postgres tolerated as num
  final String? unit; // e.g. "hour", "session"

  const SpacePrice({
    required this.id,
    required this.venueSpaceId,
    required this.isActive,
    required this.currency,
    required this.amount,
    this.label,
    this.unit,
  });

  factory SpacePrice.fromMap(Map<String, dynamic> row) {
    final m = asMap(row);
    final amt = m['amount'] ?? m['price'] ?? 0;
    return SpacePrice(
      id: (m['id'] ?? '').toString(),
      venueSpaceId: (m['venue_space_id'] ?? m['space_id'] ?? '').toString(),
      isActive: asBool(m['is_active']) ?? true,
      label: m['label']?.toString(),
      currency: (m['currency'] ?? 'USD').toString(),
      amount: (amt is num) ? amt : num.tryParse(amt.toString()) ?? 0,
      unit: m['unit']?.toString(),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'id': id,
    'venue_space_id': venueSpaceId,
    'is_active': isActive,
    'currency': currency,
    'amount': amount,
    if (label != null) 'label': label,
    if (unit != null) 'unit': unit,
  };

  Map<String, dynamic> toUpdateMap() => {
    'venue_space_id': venueSpaceId,
    'is_active': isActive,
    'currency': currency,
    'amount': amount,
    'label': label,
    'unit': unit,
  };
}
