// KAN-1000: a recording fake of the post-activity repository and the
// harness the G-02 / G-03 tests pump.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/post_activity/data/post_activity_repository.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixed "now" of every test: 2026-11-18 21:00 local.
final DateTime kNow = DateTime(2026, 11, 18, 21);

const List<RatingDimension> kDims = [
  RatingDimension(
    key: 'sportsmanship',
    labelEn: 'Sportsmanship',
    labelAr: 'الروح الرياضية',
    subjects: {RatingSubject.player, RatingSubject.organiser},
  ),
  RatingDimension(
    key: 'cleanliness',
    labelEn: 'Cleanliness',
    labelAr: 'النظافة',
    subjects: {RatingSubject.venue},
  ),
];

RatingFlow flowOf(
  RatingFlowState state, {
  Map<String, int> playerMine = const {},
}) => RatingFlow(
  state: state,
  closesAt: kNow.add(const Duration(hours: 47)),
  players: [RatingTarget(id: 'p1', name: 'Omar', mine: playerMine)],
  organiser: const RatingTarget(id: 'o1', name: 'Sara'),
  venue: const RatingTarget(id: 'v1', name: 'Al Wasl Court'),
);

class FakePostRepo implements PostActivityRepository {
  FakePostRepo({required this.flowValue, required this.tally});

  RatingFlow flowValue;

  /// Set to make flow() fail.
  Failure? flowFailure;
  Result<ResultTally, Failure> tally;

  /// Each write's answer; Ok by default.
  Failure? failure;

  /// Holds every write open until completed.
  Completer<void>? gate;

  /// Applied after a successful write (the server's next state).
  void Function()? afterWrite;

  final List<String> calls = <String>[];
  int flowReads = 0;
  int resultReads = 0;

  @override
  Future<Result<RatingFlow, Failure>> flow(String eventId) async {
    flowReads++;
    if (flowFailure != null) return Err(flowFailure!);
    return Ok(flowValue);
  }

  @override
  Future<Result<List<RatingDimension>, Failure>> dimensions() async =>
      const Ok(kDims);

  @override
  Future<Result<ResultTally, Failure>> result(String eventId) async {
    resultReads++;
    return tally;
  }

  Future<Result<T, Failure>> _w<T>(String call, T value) async {
    calls.add(call);
    await gate?.future;
    if (failure != null) return Err(failure!);
    afterWrite?.call();
    return Ok(value);
  }

  @override
  Future<Result<(int, int), Failure>> submitScore(
    String eventId,
    Score score,
    String side,
  ) => _w('score:${score.a}-${score.b}:$side', (1, 2));

  @override
  Future<Result<void, Failure>> rate(
    String eventId,
    RatingSubject subject,
    String? targetUserId,
    Map<String, int> scores,
  ) => _w('rate:${subject.name}:${targetUserId ?? ''}:$scores', null);

  @override
  Future<Result<void, Failure>> submitFlow(String eventId) =>
      _w('submit', null);

  @override
  Future<Result<void, Failure>> dismiss(String eventId) => _w('dismiss', null);

  @override
  Future<Result<void, Failure>> approve(String eventId) => _w('approve', null);

  @override
  Future<Result<void, Failure>> setFinal(String eventId, Score score) =>
      _w('final:${score.a}-${score.b}', null);
}

Future<void> pumpPost(
  WidgetTester tester,
  FakePostRepo repo,
  Widget home, {
  Locale locale = const Locale('en'),
  bool use24h = false,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        postActivityRepositoryProvider.overrideWithValue(repo),
        postActivityNowProvider.overrideWithValue(() => kNow),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
          child: DabblerToastProvider(child: child!),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const List<Locale> kLocales = <Locale>[Locale('en'), Locale('ar')];

AppLocalizations lOf(Locale locale) => lookupAppLocalizations(locale);
