import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
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
  Failure? rsvpFailure;
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
  }) async => const Ok(<NearbyMeetup>[]);

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
      const Ok(false);

  @override
  Future<Result<List<MeetupSport>, Failure>> soloSports() async => Ok(sports);

  @override
  Future<Result<List<MeetupSportVariant>, Failure>> sportVariants(
    String sportId,
  ) async => const Ok(<MeetupSportVariant>[]);

  @override
  Future<Result<String, Failure>> create(
    CreateMeetupInput input, {
    String actorType = 'organiser',
  }) async => const Ok('new');

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
  Future<Result<void, Failure>> cancel(String meetupId) async => const Ok(null);

  @override
  Future<Result<MeetupCard, Failure>> update(UpdateMeetupInput input) async =>
      Ok(card);

  @override
  Future<Result<RsvpStatus, Failure>> decideRequest(
    String meetupId,
    String userId,
    MeetupDecision decision,
  ) async => const Ok(RsvpStatus.going);

  @override
  Future<Result<RsvpStatus, Failure>> removeAttendee(
    String meetupId,
    String userId,
  ) async => const Ok(RsvpStatus.cancelled);
}

class _DeniedLocation extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
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
);

/// Builds [home] under the app's localisation and theme, LTR or RTL.
Future<void> pumpMeetups(
  WidgetTester tester,
  Widget home,
  FakeMeetupRepository repo, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meetupRepositoryProvider.overrideWithValue(repo),
        activeLocationProvider.overrideWith(_DeniedLocation.new),
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
