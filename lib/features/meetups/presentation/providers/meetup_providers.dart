import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import '../../data/datasources/meetup_datasource.dart';
import '../../data/datasources/supabase_meetup_datasource.dart';
import '../../data/repositories/meetup_repository_impl.dart';
import '../../domain/models/meetup_enums.dart';
import '../../domain/models/meetup_inputs.dart';
import '../../domain/models/meetup_models.dart';
import '../../domain/repositories/meetup_repository.dart';

// infra -> repo ---------------------------------------------------------------

final meetupDataSourceProvider = Provider<MeetupDataSource>(
  (ref) => SupabaseMeetupDataSource(ref.watch(supabaseClientProvider)),
);

final meetupRepositoryProvider = Provider<MeetupRepository>(
  (ref) => MeetupRepositoryImpl(ref.watch(meetupDataSourceProvider)),
);

/// Unwraps a Result for AsyncValue consumers; the Failure becomes the error.
Future<T> _unwrap<T>(Future<Result<T, Failure>> f) async {
  final r = await f;
  return r.fold((e) => throw e, (v) => v);
}

// reads ------------------------------------------------------------------------

/// Upcoming public meetups from v_meetup_list, optionally per sport id.
final meetupListProvider = FutureProvider.autoDispose
    .family<List<MeetupListItem>, String?>(
      (ref, sportId) => _unwrap(
        ref.watch(meetupRepositoryProvider).fetchMeetups(sportId: sportId),
      ),
    );

class NearbyMeetupsQuery {
  const NearbyMeetupsQuery(this.lat, this.lng, [this.radiusMeters = 10000]);
  final double lat;
  final double lng;
  final double radiusMeters;

  @override
  bool operator ==(Object other) =>
      other is NearbyMeetupsQuery &&
      other.lat == lat &&
      other.lng == lng &&
      other.radiusMeters == radiusMeters;

  @override
  int get hashCode => Object.hash(lat, lng, radiusMeters);
}

final nearbyMeetupsProvider = FutureProvider.autoDispose
    .family<List<NearbyMeetup>, NearbyMeetupsQuery>(
      (ref, q) => _unwrap(
        ref
            .watch(meetupRepositoryProvider)
            .nearbyMeetups(
              lat: q.lat,
              lng: q.lng,
              radiusMeters: q.radiusMeters,
            ),
      ),
    );

final meetupCardProvider = FutureProvider.autoDispose
    .family<MeetupCard, String>(
      (ref, id) => _unwrap(ref.watch(meetupRepositoryProvider).meetupCard(id)),
    );

final meetupAttendeesProvider = FutureProvider.autoDispose
    .family<List<MeetupAttendee>, String>(
      (ref, id) => _unwrap(ref.watch(meetupRepositoryProvider).attendees(id)),
    );

/// The caller's RSVP eligibility / CTA for a meetup.
final meetupRsvpEligibilityProvider = FutureProvider.autoDispose
    .family<RsvpEligibility, String>(
      (ref, id) => _unwrap(ref.watch(meetupRepositoryProvider).canRsvp(id)),
    );

/// can_create_meetup(p_actor): argument is the actor's (organiser) profile id.
final canCreateMeetupProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, actorProfileId) =>
      _unwrap(ref.watch(meetupRepositoryProvider).canCreate(actorProfileId)),
);

/// Composer sports, read from the DB (sports.can_solo = true); never hardcoded.
final meetupSportsProvider = FutureProvider.autoDispose<List<MeetupSport>>(
  (ref) => _unwrap(ref.watch(meetupRepositoryProvider).soloSports()),
);

final meetupSportVariantsProvider = FutureProvider.autoDispose
    .family<List<MeetupSportVariant>, String>(
      (ref, sportId) =>
          _unwrap(ref.watch(meetupRepositoryProvider).sportVariants(sportId)),
    );

// mutations --------------------------------------------------------------------

/// Mutations return the raw Result (never throw) and invalidate affected reads.
class MeetupActionsController {
  MeetupActionsController(this._ref);
  final Ref _ref;

  MeetupRepository get _repo => _ref.read(meetupRepositoryProvider);

  void _refresh([String? meetupId]) {
    _ref.invalidate(meetupListProvider);
    _ref.invalidate(nearbyMeetupsProvider);
    if (meetupId != null) {
      _ref.invalidate(meetupCardProvider(meetupId));
      _ref.invalidate(meetupAttendeesProvider(meetupId));
      _ref.invalidate(meetupRsvpEligibilityProvider(meetupId));
    }
  }

  Future<Result<String, Failure>> create(CreateMeetupInput input) async {
    final r = await _repo.create(input);
    if (r.isSuccess) _refresh();
    return r;
  }

  Future<Result<RsvpStatus, Failure>> rsvp(
    String meetupId,
    RsvpAction action, {
    String? profileId,
  }) async {
    final r = await _repo.rsvp(meetupId, action, profileId: profileId);
    if (r.isSuccess) _refresh(meetupId);
    return r;
  }

  Future<Result<void, Failure>> cancel(String meetupId) async {
    final r = await _repo.cancel(meetupId);
    if (r.isSuccess) _refresh(meetupId);
    return r;
  }

  Future<Result<MeetupCard, Failure>> update(UpdateMeetupInput input) async {
    final r = await _repo.update(input);
    if (r.isSuccess) _refresh(input.meetupId);
    return r;
  }

  Future<Result<RsvpStatus, Failure>> decideRequest(
    String meetupId,
    String userId,
    MeetupDecision decision,
  ) async {
    final r = await _repo.decideRequest(meetupId, userId, decision);
    if (r.isSuccess) _refresh(meetupId);
    return r;
  }

  Future<Result<RsvpStatus, Failure>> removeAttendee(
    String meetupId,
    String userId,
  ) async {
    final r = await _repo.removeAttendee(meetupId, userId);
    if (r.isSuccess) _refresh(meetupId);
    return r;
  }
}

final meetupActionsProvider = Provider<MeetupActionsController>(
  MeetupActionsController.new,
);
