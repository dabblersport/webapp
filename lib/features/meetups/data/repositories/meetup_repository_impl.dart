import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import '../../domain/models/meetup_enums.dart';
import '../../domain/models/meetup_inputs.dart';
import '../../domain/models/meetup_models.dart';
import '../../domain/repositories/meetup_repository.dart';
import '../datasources/meetup_datasource.dart';
import '../mappers/meetup_failures.dart';
import '../mappers/meetup_mappers.dart';

class MeetupRepositoryImpl implements MeetupRepository {
  const MeetupRepositoryImpl(this._ds);
  final MeetupDataSource _ds;

  Future<Result<T, Failure>> _guard<T>(Future<T> Function() body) =>
      Result.guard<T, Failure>(body, MeetupFailures.from);

  @override
  Future<Result<List<MeetupListItem>, Failure>> fetchMeetups({
    String? sportId,
    int limit = 20,
    int offset = 0,
  }) => _guard(() async {
    final rows = await _ds.fetchMeetupList(
      sportId: sportId,
      limit: limit,
      offset: offset,
    );
    return rows.map(MeetupMappers.listItem).toList();
  });

  @override
  Future<Result<List<NearbyMeetup>, Failure>> nearbyMeetups({
    required double lat,
    required double lng,
    double radiusMeters = 10000,
  }) => _guard(() async {
    final rows = await _ds.nearby(lat, lng, radiusMeters);
    return rows.map(MeetupMappers.nearby).toList();
  });

  @override
  Future<Result<MeetupCard, Failure>> meetupCard(
    String meetupId, {
    String profileType = 'player',
  }) => _guard(
    () async => MeetupMappers.card(await _ds.card(meetupId, profileType)),
  );

  @override
  Future<Result<List<MeetupAttendee>, Failure>> attendees(
    String meetupId, {
    RsvpStatus? status,
    int limit = 50,
    int offset = 0,
  }) => _guard(() async {
    final rows = await _ds.attendees(
      meetupId,
      status: status?.dbValue,
      limit: limit,
      offset: offset,
    );
    return rows.map(MeetupMappers.attendee).toList();
  });

  @override
  Future<Result<RsvpEligibility, Failure>> canRsvp(String meetupId) => _guard(
    () async => MeetupMappers.eligibility(await _ds.canRsvp(meetupId)),
  );

  @override
  Future<Result<bool, Failure>> canCreate(String actorProfileId) =>
      _guard(() => _ds.canCreate(actorProfileId));

  @override
  Future<Result<List<MeetupSport>, Failure>> soloSports() => _guard(
    () async => (await _ds.soloSports()).map(MeetupMappers.sport).toList(),
  );

  @override
  Future<Result<List<MeetupSportVariant>, Failure>> sportVariants(
    String sportId,
  ) => _guard(
    () async =>
        (await _ds.sportVariants(sportId)).map(MeetupMappers.variant).toList(),
  );

  @override
  Future<Result<String, Failure>> create(
    CreateMeetupInput input, {
    String actorType = 'organiser',
  }) => _guard(() => _ds.create(input, actorType: actorType));

  @override
  Future<Result<RsvpStatus, Failure>> rsvp(
    String meetupId,
    RsvpAction action, {
    String? profileId,
  }) => _guard(
    () async => RsvpStatus.fromDb(
      await _ds.rsvp(meetupId, action.rpcValue, profileId: profileId),
    ),
  );

  @override
  Future<Result<void, Failure>> cancel(String meetupId) =>
      _guard(() => _ds.cancel(meetupId));

  @override
  Future<Result<MeetupCard, Failure>> update(UpdateMeetupInput input) =>
      _guard(() async => MeetupMappers.card(await _ds.update(input)));

  @override
  Future<Result<RsvpStatus, Failure>> decideRequest(
    String meetupId,
    String userId,
    MeetupDecision decision,
  ) => _guard(
    () async => RsvpStatus.fromDb(
      await _ds.decideRequest(meetupId, userId, decision.rpcValue),
    ),
  );

  @override
  Future<Result<RsvpStatus, Failure>> removeAttendee(
    String meetupId,
    String userId,
  ) => _guard(
    () async => RsvpStatus.fromDb(await _ds.removeAttendee(meetupId, userId)),
  );
}
