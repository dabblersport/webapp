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

  /// Host edit; returns the refreshed card.
  Future<Result<MeetupCard, Failure>> update(UpdateMeetupInput input);

  /// Host approves/declines a pending request. Approve may yield
  /// [RsvpStatus.interested] when the meetup is full; decline yields cancelled.
  Future<Result<RsvpStatus, Failure>> decideRequest(
    String meetupId,
    String userId,
    MeetupDecision decision,
  );

  /// Host removes an attendee; yields [RsvpStatus.cancelled].
  Future<Result<RsvpStatus, Failure>> removeAttendee(
    String meetupId,
    String userId,
  );
}
