import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/core/services/analytics/analytics_service.dart';
import 'package:dabbler/data/models/check_in/check_in_status.dart';
import 'package:dabbler/features/rewards/controllers/check_in_controller.dart';
import 'package:dabbler/features/rewards/providers/check_in_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'analytics_mocks.dart';

const _piiKeys = ['email', 'phone', 'name', 'username'];

CheckInResponse _response({bool first = true}) => CheckInResponse(
  success: true,
  message: 'ok',
  streakCount: 3,
  totalDaysCompleted: 3,
  isCompleted: false,
  isFirstCheckInToday: first,
);

void main() {
  late MockEventSink sink;
  String? userId;

  setUp(() {
    sink = MockEventSink();
    userId = 'user-1';
    when(sink.send(any, any)).thenAnswer((_) async {});
    AnalyticsService.sinkOverride = (n, p) => sink.send(n, p);
    AnalyticsService.userIdOverride = () => userId;
  });

  tearDown(AnalyticsService.resetForTest);

  group('signup', () {
    test('fires once for a new OTP user, even if called twice', () async {
      await AnalyticsService.trackSignup(method: 'otp');
      await AnalyticsService.trackSignup(method: 'otp');
      verify(sink.send('signup', {'method': 'otp'})).called(1);
    });

    test('fires once for a new Google user', () async {
      await AnalyticsService.trackOAuthSignup(
        const GoogleSignInResultGoToOnboarding(email: 'a@b.c'),
        provider: 'google',
      );
      verify(sink.send('signup', {'method': 'google'})).called(1);
    });

    test('fires once for a new Apple user with a phone', () async {
      await AnalyticsService.trackOAuthSignup(
        const GoogleSignInResultGoToPhoneOtp(phone: '+1', email: 'a@b.c'),
        provider: 'apple',
      );
      verify(sink.send('signup', {'method': 'apple'})).called(1);
    });

    test('does not fire for a returning user', () async {
      await AnalyticsService.trackOAuthSignup(
        const GoogleSignInResultGoToHome(),
        provider: 'google',
      );
      await AnalyticsService.trackOAuthSignup(
        const GoogleSignInResultRequirePassword(email: 'a@b.c'),
        provider: 'apple',
      );
      verifyNever(sink.send('signup', any));
    });
  });

  group('check_in', () {
    ProviderContainer containerWith(MockCheckInRepository repo) {
      final c = ProviderContainer(
        overrides: [
          checkInRepositoryProvider.overrideWithValue(repo),
          checkInStatusDetailProvider.overrideWith(
            (ref) => const CheckInStatusDetail(
              streakCount: 0,
              totalDaysCompleted: 0,
              isCompleted: false,
              checkedInToday: false,
              daysRemaining: 14,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('fires once on a successful performCheckIn', () async {
      final repo = MockCheckInRepository();
      when(
        repo.performCheckIn(deviceInfo: anyNamed('deviceInfo')),
      ).thenAnswer((_) async => Ok(_response()));
      final c = containerWith(repo);

      await c.read(checkInControllerProvider.notifier).performCheckIn();
      await Future<void>.delayed(Duration.zero);

      verify(
        sink.send('check_in', {'streak_count': 3, 'first_today': true}),
      ).called(1);
    });

    test('does not fire on a failed performCheckIn', () async {
      final repo = MockCheckInRepository();
      when(
        repo.performCheckIn(deviceInfo: anyNamed('deviceInfo')),
      ).thenAnswer((_) async => const Err(ServerFailure()));
      final c = containerWith(repo);

      await c.read(checkInControllerProvider.notifier).performCheckIn();
      await Future<void>.delayed(Duration.zero);

      verifyNever(sink.send('check_in', any));
    });
  });

  group('properties', () {
    test('trackEvent adds no user_id', () async {
      AnalyticsService.userIdOverride = () => 'user-1';
      await AnalyticsService.setUser('user-1');
      await AnalyticsService.trackEvent('x', {'a': 1});
      verify(sink.send('x', {'a': 1})).called(1);
      verify(sink.send('identify', {})).called(1);
    });

    test('the four launch events carry no PII keys', () async {
      const service = AnalyticsService();
      await AnalyticsService.trackSignup(method: 'otp');
      await service.trackCheckIn(streakCount: 2, firstToday: false);
      await service.trackGameCreated(
        gameId: 'g1',
        sportType: 'padel',
        playerCount: 4,
        price: null,
        venueType: 'venue',
        duration: '60m',
      );
      await service.trackGameJoined(
        gameId: 'g1',
        sportType: 'padel',
        joinMethod: 'open',
        timeToJoin: 10,
      );

      final captured = verify(sink.send(captureAny, captureAny)).captured;
      final names = <String>[];
      for (var i = 0; i < captured.length; i += 2) {
        names.add(captured[i] as String);
        final props = captured[i + 1] as Map<String, Object?>;
        for (final k in props.keys) {
          expect(_piiKeys, isNot(contains(k)), reason: '${captured[i]}.$k');
        }
        expect(props.containsKey('user_id'), isFalse);
      }
      expect(
        names,
        containsAll(['signup', 'check_in', 'game_created', 'game_joined']),
      );
    });

    test('game_created price is null, not 0', () async {
      await const AnalyticsService().trackGameCreated(
        gameId: 'g1',
        sportType: 'padel',
        playerCount: 4,
        price: null,
        venueType: 'venue',
        duration: '60m',
      );
      final props =
          verify(sink.send('game_created', captureAny)).captured.single
              as Map<String, Object?>;
      expect(props['price'], isNull);
    });
  });
}
