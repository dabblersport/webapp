import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_follow.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_inputs.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/domain/repositories/meetup_repository.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A recording fake of the meetup repository.
class FakeMeetupRepository implements MeetupRepository {
  List<MeetupListItem> list = <MeetupListItem>[];
  Object? listError;
  Completer<void>? listGate;
  MeetupCard card = const MeetupCard(id: 'm1');
  RsvpEligibility eligibility = const RsvpEligibility(
    allowed: true,
    cta: RsvpCta.rsvpGoing,
  );
  List<MeetupAttendee> attendeeList = <MeetupAttendee>[];
  List<MeetupSport> sports = const <MeetupSport>[
    MeetupSport(id: 's1', nameEn: 'Running', nameAr: 'جري'),
    MeetupSport(id: 's2', nameEn: 'Yoga', nameAr: 'يوغا'),
  ];
  List<NearbyMeetup> nearbyList = <NearbyMeetup>[];
  Failure? rsvpFailure;
  Failure? sportsFailure;
  Failure? createFailure;
  bool canCreateResult = true;
  final List<CreateMeetupInput> createCalls = <CreateMeetupInput>[];
  List<MeetupSportVariant> variants = const <MeetupSportVariant>[
    MeetupSportVariant(id: 'v1', sportId: 's1', nameEn: 'Solo'),
  ];
  final List<UpdateMeetupInput> updateCalls = <UpdateMeetupInput>[];
  final List<(String, String, String)> decideCalls =
      <(String, String, String)>[];
  final List<(String, String)> removeCalls = <(String, String)>[];
  final List<String> cancelCalls = <String>[];
  Failure? manageFailure;
  final List<(String, RsvpAction)> rsvpCalls = <(String, RsvpAction)>[];

  @override
  Future<Result<List<MeetupListItem>, Failure>> fetchMeetups({
    String? sportId,
    int limit = 20,
    int offset = 0,
  }) async {
    await listGate?.future;
    if (listError != null) return Err(Failure(message: '$listError'));
    return Ok(list);
  }

  @override
  Future<Result<List<NearbyMeetup>, Failure>> nearbyMeetups({
    required double lat,
    required double lng,
    double radiusMeters = 10000,
  }) async => Ok(nearbyList);

  @override
  Future<Result<MeetupCard, Failure>> meetupCard(
    String meetupId, {
    String profileType = 'player',
  }) async => Ok(card);

  @override
  Future<Result<List<MeetupAttendee>, Failure>> attendees(
    String meetupId, {
    RsvpStatus? status,
    int limit = 50,
    int offset = 0,
  }) async => Ok(attendeeList);

  @override
  Future<Result<RsvpEligibility, Failure>> canRsvp(String meetupId) async =>
      Ok(eligibility);

  @override
  Future<Result<bool, Failure>> canCreate(String actorProfileId) async =>
      Ok(canCreateResult);

  @override
  Future<Result<List<MeetupSport>, Failure>> soloSports() async =>
      sportsFailure != null ? Err(sportsFailure!) : Ok(sports);

  @override
  Future<Result<List<MeetupSportVariant>, Failure>> sportVariants(
    String sportId,
  ) async => Ok(variants);

  @override
  Future<Result<String, Failure>> create(
    CreateMeetupInput input, {
    String actorType = 'organiser',
  }) async {
    createCalls.add(input);
    if (createFailure != null) return Err(createFailure!);
    return const Ok('new1');
  }

  @override
  Future<Result<RsvpStatus, Failure>> rsvp(
    String meetupId,
    RsvpAction action, {
    String? profileId,
  }) async {
    rsvpCalls.add((meetupId, action));
    if (rsvpFailure != null) return Err(rsvpFailure!);
    return const Ok(RsvpStatus.going);
  }

  @override
  Future<Result<void, Failure>> cancel(String meetupId) async {
    cancelCalls.add(meetupId);
    if (manageFailure != null) return Err(manageFailure!);
    return const Ok(null);
  }

  @override
  Future<Result<MeetupCard, Failure>> update(UpdateMeetupInput input) async {
    updateCalls.add(input);
    if (manageFailure != null) return Err(manageFailure!);
    return Ok(card);
  }

  @override
  Future<Result<RsvpStatus, Failure>> decideRequest(
    String meetupId,
    String userId,
    MeetupDecision decision,
  ) async {
    decideCalls.add((meetupId, userId, decision.rpcValue));
    if (manageFailure != null) return Err(manageFailure!);
    return const Ok(RsvpStatus.going);
  }

  @override
  Future<Result<RsvpStatus, Failure>> removeAttendee(
    String meetupId,
    String userId,
  ) async {
    removeCalls.add((meetupId, userId));
    if (manageFailure != null) return Err(manageFailure!);
    return const Ok(RsvpStatus.cancelled);
  }
}

class _DeniedLocation extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

class _ReadyLocation extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    const ActiveLocation(
      lat: 25.2,
      lng: 55.27,
      source: ActiveLocationSource.saved,
      area: Area(
        id: 'a1',
        name: 'Dubai Marina',
        district: 'Marina',
        city: 'Dubai',
        country: 'AE',
        centerLat: 25.2,
        centerLng: 55.27,
      ),
    ),
  );
}

/// Records follow presses.
class FollowLog {
  final List<(String, String, bool)> calls = <(String, String, bool)>[];
  bool following = false;
}

MeetupListItem meetupRow(
  String id, {
  String title = 'Sunrise run',
  Duration startsIn = const Duration(days: 1),
  int? capacity = 40,
  int going = 24,
  String? my,
  RsvpPolicy policy = RsvpPolicy.open,
  bool cancelled = false,
  int? minSkill,
  int? maxSkill,
  String? vibeKey,
  List<MeetupAvatar> faces = const <MeetupAvatar>[],
}) => MeetupListItem(
  id: id,
  title: title,
  startAt: DateTime.now().add(startsIn),
  capacity: capacity,
  goingCount: going,
  myRsvpStatus: my,
  rsvpPolicy: policy,
  isCancelled: cancelled,
  sportNameEn: 'Running',
  venueName: 'Kite Beach',
  minSkill: minSkill,
  maxSkill: maxSkill,
  attendeeAvatars: faces,
  vibeKey: vibeKey,
);

/// Builds [home] under the app's localisation and theme, LTR or RTL.
Future<void> pumpMeetups(
  WidgetTester tester,
  Widget home,
  FakeMeetupRepository repo, {
  Locale locale = const Locale('en'),
  bool locationReady = false,
  FollowLog? follow,
  List<Override> overrides = const <Override>[],
}) async {
  final log = follow ?? FollowLog();
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meetupRepositoryProvider.overrideWithValue(repo),
        activeLocationProvider.overrideWith(
          locationReady ? _ReadyLocation.new : _DeniedLocation.new,
        ),
        myProfileIdProvider.overrideWith((ref) async => 'me'),
        isFollowingProvider.overrideWith((ref, p) async => log.following),
        meetupFollowActionProvider.overrideWithValue(({
          required String myProfileId,
          required String targetProfileId,
          required bool currentlyFollowing,
        }) async {
          log.calls.add((myProfileId, targetProfileId, currentlyFollowing));
        }),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        home: home,
      ),
    ),
  );
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A container with the fake repository, for provider-only tests.
ProviderContainer makeContainer(
  FakeMeetupRepository repo, [
  List<Override> overrides = const <Override>[],
]) {
  final c = ProviderContainer(
    overrides: <Override>[
      meetupRepositoryProvider.overrideWithValue(repo),
      ...overrides,
    ],
  );
  addTearDown(c.dispose);
  return c;
}
