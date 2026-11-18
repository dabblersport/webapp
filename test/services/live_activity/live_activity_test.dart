import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/constants/timing/notification_timing.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/services/live_activity/live_activity_controller.dart';
import 'package:dabbler/services/live_activity/live_activity_providers.dart';
import 'package:dabbler/services/live_activity/live_activity_service.dart';
import 'package:dabbler/services/live_activity/live_activity_service_mobile.dart';
import 'package:dabbler/services/live_activity/live_activity_service_stub.dart';

Map<String, Object?> content(int v, {String state = 'checkin_open'}) => {
  'state': state,
  'state_version': v,
  'event_id': 'e1',
  'event_type': 'game',
  'title': 'Padel',
  'start_at': 1700000000,
  'checked_in': false,
  'role': 'participant',
};

Map<String, Object?> session({
  String status = 'planned',
  bool needsLocal = true,
  int v = 1,
}) => {
  'session_id': 's1',
  'event_id': 'e1',
  'platform': 'ios',
  'status': status,
  'needs_local_start': needsLocal,
  'state_version': v,
  'has_push_token': false,
  'content': content(v),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('test/la');
  final calls = <MethodCall>[];
  var active = <Map<String, Object?>>[];
  Object? Function(MethodCall)? override;
  var signedIn = true;
  var clock = DateTime.utc(2026, 11, 18, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    signedIn = true;
    clock = DateTime.utc(2026, 11, 18, 12);
    calls.clear();
    active = [];
    override = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          calls.add(call);
          if (override != null) return override!(call);
          switch (call.method) {
            case 'getCapabilities':
              return {
                'supported': true,
                'permission': 'granted',
                'push_to_start': false,
              };
            case 'start':
              return {'activity_id': 'a1', 'push_token': 'tok'};
            case 'listActive':
              return active;
          }
          return null;
        });
  });

  late List<(String, Map<String, dynamic>)> rpcs;
  late Object? Function(String) rpcResult;

  LiveActivityController controller(LiveActivityService service) {
    rpcs = [];
    rpcResult = (_) => null;
    return LiveActivityController(
      service: service,
      rpc: (fn, p) async {
        rpcs.add((fn, p));
        return rpcResult(fn);
      },
      installationId: () async => 'inst-1',
      hasSession: () => signedIn,
      now: () => clock,
    );
  }

  final service = ChannelLiveActivityService(
    methods: methods,
    events: const EventChannel('test/la/events'),
  );

  test('content version rule: not strictly higher is ignored', () {
    final c = LiveActivityContent.tryParse(content(5))!;
    expect(c.isNewerThan(null), isTrue);
    expect(c.isNewerThan(4), isTrue);
    expect(c.isNewerThan(5), isFalse);
    expect(c.isNewerThan(6), isFalse);
    expect(c.startAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
  });

  test(
    'needs_local_start session is started and its token registered',
    () async {
      final c = controller(service);
      rpcResult = (fn) => [session()];
      final r = await c.sync();
      expect(r.requireValue, isTrue);
      final start = calls.firstWhere((m) => m.method == 'start');
      expect((start.arguments as Map)['session_id'], 's1');
      expect((start.arguments as Map)['attributes'], {
        'event_id': 'e1',
        'event_type': 'game',
        'title': 'Padel',
      });
      expect(rpcs.first.$1, SupabaseConfig.rpcLiveActivitySessions);
      expect(rpcs.first.$2, {'p_installation_id': 'inst-1'});
      final reg = rpcs.last;
      expect(reg.$1, SupabaseConfig.rpcLiveActivityRegister);
      expect(reg.$2['p_session_id'], 's1');
      expect(reg.$2['p_activity_id'], 'a1');
      expect(reg.$2['p_push_token'], 'tok');
      expect(c.versionOf('s1'), 1);
    },
  );

  test('a session without needs_local_start is not started locally', () async {
    final c = controller(service);
    rpcResult = (fn) => [session(needsLocal: false)];
    await c.sync();
    expect(calls.where((m) => m.method == 'start'), isEmpty);
  });

  test('older or equal versions are ignored, newer applied', () async {
    final c = controller(service);
    active = [
      {'session_id': 's1', 'activity_id': 'a1', 'state_version': 3},
    ];
    rpcResult = (fn) => [session(status: 'active', needsLocal: false, v: 3)];
    await c.sync();
    expect(calls.where((m) => m.method == 'update'), isEmpty);

    rpcResult = (fn) => [session(status: 'active', needsLocal: false, v: 2)];
    await c.sync();
    expect(calls.where((m) => m.method == 'update'), isEmpty);

    rpcResult = (fn) => [session(status: 'active', needsLocal: false, v: 4)];
    active = [];
    await c.sync();
    expect(calls.where((m) => m.method == 'update'), hasLength(1));
    expect(c.versionOf('s1'), 4);
  });

  test('a session the server ended is ended on the device', () async {
    final c = controller(service);
    active = [
      {'session_id': 's1', 'activity_id': 'a1', 'state_version': 2},
    ];
    rpcResult = (fn) => [session(status: 'ended', needsLocal: false, v: 3)];
    await c.sync();
    final end = calls.singleWhere((m) => m.method == 'end');
    expect((end.arguments as Map)['activity_id'], 'a1');
    expect(((end.arguments as Map)['content'] as Map)['state_version'], 3);
  });

  test('push-to-start token is registered once per value', () async {
    final c = controller(service);
    expect((await c.registerPushToStart('p1')).isSuccess, isTrue);
    await c.registerPushToStart('p1');
    expect(rpcs, hasLength(1));
    expect(rpcs.single.$1, SupabaseConfig.rpcLiveActivityRegisterPushToStart);
    expect(rpcs.single.$2, {'p_installation_id': 'inst-1', 'p_token': 'p1'});
  });

  test('opt-out calls the RPC and ends what is shown', () async {
    final c = controller(service);
    active = [
      {'session_id': 's1', 'activity_id': 'a1', 'state_version': 1},
    ];
    rpcResult = (fn) => fn == SupabaseConfig.rpcLiveActivitySessions
        ? [session(status: 'active', needsLocal: false)]
        : null;
    await c.sync();
    final r = await c.setOptedOut(true);
    expect(r.isSuccess, isTrue);
    expect(rpcs.last.$1, SupabaseConfig.rpcLiveActivityOptOut);
    expect(rpcs.last.$2, {'p_installation_id': 'inst-1', 'p_opted_out': true});
    expect(calls.where((m) => m.method == 'end'), hasLength(1));
  });

  test('an RPC failure is returned, not thrown', () async {
    final c = LiveActivityController(
      service: service,
      rpc: (fn, p) async => throw StateError('down'),
      installationId: () async => 'inst-1',
      hasSession: () => true,
    );
    final r = await c.sync();
    expect(r.isFailure, isTrue);
  });

  group('error mapping', () {
    Future<Failure> failWith(String code) async {
      override = (call) => call.method == 'start'
          ? throw PlatformException(code: code, message: 'x')
          : null;
      final r = await service.start(
        sessionId: 's1',
        content: LiveActivityContent.tryParse(content(1))!,
      );
      return r.requireError;
    }

    test('contract codes map to failure categories', () async {
      expect(
        (await failWith('permission_denied')).category,
        FailureCode.forbidden,
      );
      expect((await failWith('not_found')).category, FailureCode.notFound);
      expect(
        (await failWith('invalid_payload')).category,
        FailureCode.validation,
      );
      expect(
        (await failWith('limit_reached')).category,
        FailureCode.rateLimited,
      );
      final f = await failWith('boom');
      expect(f.category, FailureCode.unknown);
      expect(f.code, 'boom');
    });

    test('missing plugin is unsupported; capabilities never fail', () async {
      final none = ChannelLiveActivityService(
        methods: const MethodChannel('test/none'),
      );
      expect(await none.isSupported(), isFalse);
      final r = await none.listActive();
      expect(r.requireError.code, LiveActivityErrorCode.unsupported);
    });
  });

  group('stub (web / unsupported)', () {
    const stub = StubLiveActivityService();

    test('reports unsupported and never throws', () async {
      expect(await stub.isSupported(), isFalse);
      expect(
        (await stub.capabilities()).permission,
        LiveActivityPermission.unsupported,
      );
      final r = await stub.start(
        sessionId: 's1',
        content: LiveActivityContent.tryParse(content(1))!,
      );
      expect(r.requireError.code, LiveActivityErrorCode.unsupported);
      expect((await stub.listActive()).requireValue, isEmpty);
      expect(await stub.events.isEmpty, isTrue);
    });

    test('the controller on the stub does nothing', () async {
      final c = controller(stub);
      final r = await c.sync();
      expect(r.requireValue, isFalse);
      expect(rpcs, isEmpty);
    });
  });

  test('events parse', () {
    expect(
      LiveActivityEvent.fromMap({'type': 'push_to_start_token', 'token': 't'}),
      isA<LiveActivityPushToStartToken>(),
    );
    expect(
      LiveActivityEvent.fromMap({
        'type': 'activity_ended',
        'session_id': 's1',
        'reason': 'user_dismissed',
      }),
      isA<LiveActivityEndedOnDevice>(),
    );
    expect(LiveActivityEvent.fromMap({'type': 'nope'}), isNull);
  });

  group('KAN-1005 follow-up', () {
    late StreamController<LiveActivityEvent> events;
    late _EventsService evService;
    setUp(() {
      events = StreamController<LiveActivityEvent>();
      evService = _EventsService(service, events.stream);
    });
    tearDown(() => unawaited(events.close()));

    Future<void> pump() => Future<void>.delayed(Duration.zero);
    int sessionReads() => rpcs
        .where((r) => r.$1 == SupabaseConfig.rpcLiveActivitySessions)
        .length;
    List<(String, Map<String, dynamic>)> registers() => rpcs
        .where((r) => r.$1 == SupabaseConfig.rpcLiveActivityRegister)
        .toList();

    test(
      'activity_token maps event_id to the session of the last read',
      () async {
        final c = controller(evService)..start();
        rpcResult = (fn) => fn == SupabaseConfig.rpcLiveActivitySessions
            ? [session(needsLocal: false)]
            : null;
        await c.sync();
        events.add(
          LiveActivityEvent.fromMap({
            'type': 'activity_token',
            'event_id': 'e1',
            'activity_id': 'a9',
            'token': 't1',
          })!,
        );
        await pump();
        expect(sessionReads(), 1);
        expect(registers().single.$2['p_session_id'], 's1');
        expect(registers().single.$2['p_activity_id'], 'a9');
        expect(registers().single.$2['p_push_token'], 't1');
      },
    );

    test('an unknown event_id re-reads the sessions once', () async {
      final c = controller(evService)..start();
      rpcResult = (fn) => fn == SupabaseConfig.rpcLiveActivitySessions
          ? sessionReads() == 1
                ? <Object?>[]
                : [session(needsLocal: false)]
          : null;
      await c.sync();
      events.add(
        LiveActivityEvent.fromMap({
          'type': 'activity_token',
          'event_id': 'e1',
          'activity_id': 'a9',
          'token': 't1',
        })!,
      );
      await pump();
      await pump();
      expect(sessionReads(), 2);
      expect(registers().single.$2['p_session_id'], 's1');
    });

    test('token rotation registers each token', () async {
      final c = controller(evService)..start();
      rpcResult = (fn) => fn == SupabaseConfig.rpcLiveActivitySessions
          ? [session(needsLocal: false)]
          : null;
      await c.sync();
      for (final t in ['t1', 't2']) {
        events.add(
          LiveActivityEvent.fromMap({
            'type': 'activity_token',
            'event_id': 'e1',
            'activity_id': 'a9',
            'token': t,
          })!,
        );
        await pump();
      }
      expect(registers().map((r) => r.$2['p_push_token']), ['t1', 't2']);
    });

    test('a user-dismissed activity is not started again', () async {
      final c = controller(evService)..start();
      rpcResult = (fn) =>
          fn == SupabaseConfig.rpcLiveActivitySessions ? [session()] : null;
      await c.sync();
      expect(calls.where((m) => m.method == 'start'), hasLength(1));
      events.add(
        LiveActivityEvent.fromMap({
          'type': 'activity_ended',
          'event_id': 'e1',
          'activity_id': 'a1',
          'reason': 'user_dismissed',
        })!,
      );
      await pump();
      await pump();
      expect(c.activities, isEmpty);
      await c.sync();
      expect(calls.where((m) => m.method == 'start'), hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(
          '${LiveActivityController.dismissedKeyPrefix}inst-1',
        ),
        ['s1'],
      );
    });

    test('no sync while signed out; sign-in syncs', () async {
      final c = controller(service);
      rpcResult = (fn) => [session()];
      signedIn = false;
      expect((await c.sync()).requireValue, isFalse);
      expect(rpcs, isEmpty);
      signedIn = true;
      onLiveActivityAuthChange(c, AuthChangeEvent.signedIn);
      await pump();
      await pump();
      await pump();
      expect(sessionReads(), 1);
    });

    test('sign-out ends every activity and keeps the dismissed set', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        '${LiveActivityController.dismissedKeyPrefix}inst-1',
        ['s0'],
      );
      final c = controller(service);
      active = [
        {'session_id': 's1', 'activity_id': 'a1', 'state_version': 1},
        {'session_id': 's2', 'activity_id': 'a2', 'state_version': 1},
      ];
      rpcResult = (fn) => <Object?>[];
      await c.sync();
      await c.signedOut();
      expect(
        calls
            .where((m) => m.method == 'end')
            .map((m) => m.arguments['activity_id']),
        ['a1', 'a2'],
      );
      expect(c.activities, isEmpty);
      expect(c.versionOf('s1'), isNull);
      expect(
        prefs.getStringList(
          '${LiveActivityController.dismissedKeyPrefix}inst-1',
        ),
        ['s0'],
      );
    });

    test('sync is single-flight', () async {
      final gate = Completer<void>();
      final c = LiveActivityController(
        service: service,
        rpc: (fn, p) async {
          rpcs.add((fn, p));
          await gate.future;
          return <Object?>[];
        },
        installationId: () async => 'inst-1',
        hasSession: () => true,
      );
      rpcs = [];
      final a = c.sync();
      final b = c.sync();
      expect(identical(a, b), isTrue);
      gate.complete();
      await Future.wait([a, b]);
      expect(sessionReads(), 1);
    });

    test('resume syncs are throttled', () async {
      final c = controller(service);
      rpcResult = (fn) => <Object?>[];
      await c.resumeSync();
      clock = clock.add(const Duration(seconds: 10));
      await c.resumeSync();
      expect(sessionReads(), 1);
      clock = clock.add(NotificationTiming.liveActivityResumeThrottle);
      await c.resumeSync();
      expect(sessionReads(), 2);
    });

    test('a failed register after start is retried on the next sync', () async {
      final c = controller(service);
      var failRegister = true;
      rpcResult = (fn) {
        if (fn == SupabaseConfig.rpcLiveActivityRegister && failRegister) {
          throw StateError('down');
        }
        return fn == SupabaseConfig.rpcLiveActivitySessions
            ? [session()]
            : null;
      };
      await c.sync();
      expect(registers(), hasLength(1));
      failRegister = false;
      active = [
        {'session_id': 's1', 'activity_id': 'a1', 'state_version': 1},
      ];
      await c.sync();
      expect(registers(), hasLength(2));
      expect(registers().last.$2['p_push_token'], 'tok');
      await c.sync();
      expect(registers(), hasLength(2));
    });
  });
}

/// The channel service with a test-controlled event stream.
class _EventsService implements LiveActivityService {
  _EventsService(this._inner, this.events);
  final LiveActivityService _inner;
  @override
  final Stream<LiveActivityEvent> events;

  @override
  Future<bool> isSupported() => _inner.isSupported();
  @override
  Future<LiveActivityCapabilities> capabilities() => _inner.capabilities();
  @override
  Future<Result<LiveActivityStarted, Failure>> start({
    required String sessionId,
    required LiveActivityContent content,
  }) => _inner.start(sessionId: sessionId, content: content);
  @override
  Future<Result<Unit, Failure>> update({
    required String sessionId,
    required String activityId,
    required LiveActivityContent content,
  }) => _inner.update(
    sessionId: sessionId,
    activityId: activityId,
    content: content,
  );
  @override
  Future<Result<Unit, Failure>> end({
    required String sessionId,
    required String activityId,
    LiveActivityContent? content,
    DateTime? dismissalDate,
  }) => _inner.end(
    sessionId: sessionId,
    activityId: activityId,
    content: content,
    dismissalDate: dismissalDate,
  );
  @override
  Future<Result<List<LiveActivityActive>, Failure>> listActive() =>
      _inner.listActive();
}
