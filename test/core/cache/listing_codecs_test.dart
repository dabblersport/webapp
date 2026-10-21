import 'dart:convert';

import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/venues/data/models/nearby_venue_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-605: what the listing cache stores decodes back to the same listing
/// row (the cache writes JSON text, so every case goes through jsonEncode).
Object? _wire(Object? v) => jsonDecode(jsonEncode(v));

void main() {
  test('a game row survives the cache', () {
    final g = NearbyGameModel(
      id: 'g1',
      title: 'Five-a-side',
      sportName: 'Football',
      scheduledAt: DateTime.utc(2026, 10, 22, 17),
      endAt: DateTime.utc(2026, 10, 22, 18),
      status: 'upcoming',
      venueName: 'Pitch 1',
      latitude: 25.1,
      longitude: 55.2,
      distanceMeters: 1200.5,
      playerCount: 6,
      spotsRemaining: 4,
      isPublic: true,
      isJoined: true,
      minSkill: 2,
      maxSkill: 5,
      variantNameEn: 'Futsal 5s',
      variantNameAr: 'خماسي',
      hostVerified: true,
      favoriteCount: 3,
      favouritedByMe: true,
      priceAed: 25,
    );
    final back = NearbyGameModel.fromJson(
      Map<String, dynamic>.from(_wire(g.toJson()) as Map),
    );
    expect(back.toJson(), g.toJson());
    expect(back.scheduledAt, g.scheduledAt);
    expect(back.isJoined, isTrue);
  });

  test('a venue row survives the cache', () {
    const v = NearbyVenueModel(
      id: 'v1',
      nameEn: 'Court',
      nameAr: 'ملعب',
      city: 'Dubai',
      area: 'Marina',
      isIndoor: true,
      pricePerHour: 120,
      latitude: 25.0,
      longitude: 55.1,
      distanceMeters: 800,
      sportNames: ['Padel'],
      coverUrl: 'https://x/y.jpg',
      rating: 4.5,
      ratingCount: 12,
      isVerified: true,
      isOpenNow: true,
      amenities: ['parking'],
      sports: ['Padel'],
      sportsAr: ['بادل'],
      favoriteCount: 2,
      favouritedByMe: true,
    );
    final back = NearbyVenueModel.fromJson(
      Map<String, dynamic>.from(_wire(v.toJson()) as Map),
    );
    expect(back.toJson(), v.toJson());
  });

  test('a meetup list row, nearby row and card survive the cache', () {
    final item = MeetupListItem.fromJson({
      'id': 'm1',
      'title': 'Sunday run',
      'start_at': '2026-10-25T06:00:00.000Z',
      'going_count': 4,
      'attendee_avatars': [
        {'avatar_url': 'https://x/a.png', 'display_name': 'Sam'},
      ],
    });
    final itemBack = MeetupListItem.fromJson(
      Map<String, dynamic>.from(_wire(item.toJson()) as Map),
    );
    expect(itemBack, item);

    final near = NearbyMeetup.fromJson({
      'id': 'm1',
      'title': 'Sunday run',
      'starts_at': '2026-10-25T06:00:00.000Z',
      'lat': 25.1,
      'lng': 55.2,
      'distance_m': 300.0,
    });
    expect(
      NearbyMeetup.fromJson(
        Map<String, dynamic>.from(_wire(near.toJson()) as Map),
      ),
      near,
    );

    final card = MeetupCard.fromJson({
      'id': 'm1',
      'title': 'Sunday run',
      'host': {'display_name': 'Lee', 'username': 'lee'},
      'counts': {'going': 4, 'interested': 1, 'declined': 0},
      'attendees': [
        {'avatar_url': null, 'display_name': 'Sam'},
      ],
    });
    expect(
      MeetupCard.fromJson(
        Map<String, dynamic>.from(_wire(card.toJson()) as Map),
      ),
      card,
    );
  });
}
