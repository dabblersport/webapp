import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import '../models/meetup_enums.dart';
import '../models/meetup_inputs.dart';
import '../models/meetup_models.dart';

abstract class MeetupRepository {
  Future<Result<List<MeetupListItem>, Failure>> fetchMeetups({
    String? sportId,
    int limit = 20,
    int offset = 0,
  });

  Future<Result<List<NearbyMeetup>, Failure>> nearbyMeetups({
    required double lat,
    required double lng,
    double radiusMeters = 10000,
  });

  Future<Result<MeetupCard, Failure>> meetupCard(
    String meetupId, {
    String profileType = 'player',
  });

  Future<Result<List<MeetupAttendee>, Failure>> attendees(
    String meetupId, {
    RsvpStatus? status,
    int limit = 50,
    int offset = 0,
  });

  Future<Result<RsvpEligibility, Failure>> canRsvp(String meetupId);

  Future<Result<bool, Failure>> canCreate(String actorProfileId);

  Future<Result<List<MeetupSport>, Failure>> soloSports();

  Future<Result<List<MeetupSportVariant>, Failure>> sportVariants(
    String sportId,
  );

  /// Returns the new meetup id.
  Future<Result<String, Failure>> create(
    CreateMeetupInput input, {
    String actorType = 'organiser',
  });

  /// Returns the resulting RSVP status.
  Future<Result<RsvpStatus, Failure>> rsvp(
    String meetupId,
    RsvpAction action, {
    String? profileId,
  });

  Future<Result<void, Failure>> cancel(String meetupId);

  // requires KAN-427 migration
  Future<Result<void, Failure>> update(UpdateMeetupInput input);
}
