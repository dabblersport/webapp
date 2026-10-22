import 'package:dabbler/core/config/feature_availability.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRemote implements FeatureAvailabilityRemote {
  _FakeRemote(this.result);
  Map<String, bool>? result;
  int calls = 0;

  @override
  Future<Map<String, bool>> fetch() async {
    calls++;
    final Map<String, bool>? r = result;
    if (r == null) throw Exception('offline');
    return r;
  }
}

class _MemCache implements FeatureAvailabilityCache {
  _MemCache([Map<String, bool>? seed]) : values = seed ?? <String, bool>{};
  Map<String, bool> values;

  @override
  Future<Map<String, bool>> read() async => values;

  @override
  Future<void> write(Map<String, bool> v) async => values = Map.of(v);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('evaluateFeature', () {
    test('nothing from the server keeps every compile-on feature on', () {
      for (final String id in kFeatureCompileDefaults.keys) {
        expect(
          evaluateFeature(id, const <String, bool>{}),
          kFeatureCompileDefaults[id],
        );
      }
    });

    test('remote false switches a compile-on feature off', () {
      expect(evaluateFeature('meetups', const {'meetups': false}), isFalse);
    });

    test('remote true can never enable a compile-off feature', () {
      const Map<String, bool> compile = {'payments': false};
      expect(
        evaluateFeature('payments', const {'payments': true}, compile: compile),
        isFalse,
      );
    });

    test('an unknown id is off, even if the server says on', () {
      expect(
        evaluateFeature('not_a_feature', const {'not_a_feature': true}),
        isFalse,
      );
    });

    test('a missing id keeps its compile-time default', () {
      expect(evaluateFeature('messaging', const {'meetups': false}), isTrue);
    });
  });

  test('ids match the compile-time flags, none newly enabled', () {
    expect(kFeatureCompileDefaults['meetups'], FeatureFlags.enableMeetups);
    expect(
      kFeatureCompileDefaults['booking_flow'],
      FeatureFlags.enableBookingFlow,
    );
    expect(kFeatureCompileDefaults.containsKey('payments'), isFalse);
    expect(kFeatureCompileDefaults.containsKey('data_export'), isFalse);
    expect(kFeatureCompileDefaults.containsKey('early_bird_check_in'), isFalse);
    expect(
      kFeatureCompileDefaults.containsKey('community_mobile_nav'),
      isFalse,
    );
    expect(kFeatureCompileDefaults.length, 18);
    expect(kFeatureCompileDefaults.values.every((bool v) => v), isTrue);
  });

  group('FeatureAvailabilityNotifier', () {
    test('a good fetch is applied and cached', () async {
      final _FakeRemote remote = _FakeRemote({
        'meetups': false,
        'messaging': true,
      });
      final _MemCache cache = _MemCache();
      final FeatureAvailabilityNotifier n = FeatureAvailabilityNotifier(
        userId: 'u1',
        remote: remote,
        cache: cache,
      );
      await _settle();
      expect(n.state, {'meetups': false, 'messaging': true});
      expect(cache.values, {'meetups': false, 'messaging': true});
      n.dispose();
    });

    test('an RPC error or offline keeps the last good cached value', () async {
      final _FakeRemote remote = _FakeRemote(null);
      final _MemCache cache = _MemCache({'meetups': false});
      final FeatureAvailabilityNotifier n = FeatureAvailabilityNotifier(
        userId: 'u1',
        remote: remote,
        cache: cache,
      );
      await _settle();
      expect(remote.calls, 1);
      expect(n.state, {'meetups': false});
      expect(evaluateFeature('meetups', n.state), isFalse);
      expect(evaluateFeature('messaging', n.state), isTrue);
      n.dispose();
    });

    test(
      'no cache and a failing fetch gives the compile-time defaults',
      () async {
        final FeatureAvailabilityNotifier n = FeatureAvailabilityNotifier(
          userId: 'u1',
          remote: _FakeRemote(null),
          cache: _MemCache(),
        );
        await _settle();
        expect(n.state, isEmpty);
        for (final String id in kFeatureCompileDefaults.keys) {
          expect(evaluateFeature(id, n.state), isTrue);
        }
        n.dispose();
      },
    );

    test('an id missing from the response keeps its last good value', () async {
      final _FakeRemote remote = _FakeRemote({'messaging': true});
      final _MemCache cache = _MemCache({'meetups': false});
      final FeatureAvailabilityNotifier n = FeatureAvailabilityNotifier(
        userId: 'u1',
        remote: remote,
        cache: cache,
      );
      await _settle();
      expect(n.state, {'meetups': false, 'messaging': true});
      n.dispose();
    });

    test('signed out makes no request and keeps the cached value', () async {
      final _FakeRemote remote = _FakeRemote({'meetups': true});
      final _MemCache cache = _MemCache({'meetups': false});
      final FeatureAvailabilityNotifier n = FeatureAvailabilityNotifier(
        userId: null,
        remote: remote,
        cache: cache,
      );
      await _settle();
      expect(remote.calls, 0);
      expect(n.state, {'meetups': false});
      n.dispose();
    });

    test('refresh refetches and does not poll on its own', () async {
      final _FakeRemote remote = _FakeRemote({'meetups': true});
      final FeatureAvailabilityNotifier n = FeatureAvailabilityNotifier(
        userId: 'u1',
        remote: remote,
        cache: _MemCache(),
      );
      await _settle();
      expect(remote.calls, 1);
      remote.result = {'meetups': false};
      await n.refresh();
      expect(remote.calls, 2);
      expect(n.state['meetups'], isFalse);
      n.dispose();
    });
  });
}
