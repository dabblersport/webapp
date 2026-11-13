import 'dart:async';

import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-640 R6: the first run detects the country from the IP once; a saved
/// country is never detected again; a manual choice always wins.
class _Detector {
  _Detector(this.answer);

  final Future<String> Function() answer;
  int calls = 0;

  Future<String> call() {
    calls++;
    return answer();
  }
}

Future<SelectedLocationNotifier> _make(
  _Detector d, {
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final n = SelectedLocationNotifier(detect: d.call);
  await _settle(n);
  return n;
}

Future<void> _settle(SelectedLocationNotifier n) async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

String? _country(SelectedLocationNotifier n) => n.state.valueOrNull?.country;

Future<String?> _saved() async =>
    (await SharedPreferences.getInstance()).getString('selected_country');

void main() {
  group('first run, no saved country', () {
    test('a supported detected country is preselected and saved', () async {
      final d = _Detector(() async => 'United Arab Emirates');
      final n = await _make(d);
      expect(d.calls, 1);
      expect(_country(n), 'United Arab Emirates');
      expect(await _saved(), 'United Arab Emirates');
    });

    test('an unsupported country is Global', () async {
      final d = _Detector(() async => 'France');
      final n = await _make(d);
      expect(d.calls, 1);
      expect(_country(n), 'Global');
    });

    test('a failed detection is Global, with no error', () async {
      final d = _Detector(() async => throw Exception('network'));
      final n = await _make(d);
      expect(d.calls, 1);
      expect(_country(n), 'Global');
      expect(n.state.hasError, isFalse);
      expect(await _saved(), isNull, reason: 'a failure is tried again later');
    });

    test('the detector answering Global (blocked) is Global', () async {
      final n = await _make(_Detector(() async => 'Global'));
      expect(_country(n), 'Global');
    });
  });

  group('no re-detect', () {
    test('a saved country is not detected again', () async {
      final d = _Detector(() async => 'Qatar');
      final n = await _make(d, prefs: {'selected_country': 'Egypt'});
      expect(d.calls, 0);
      expect(_country(n), 'Egypt');
    });

    test('a saved Global choice is not detected again', () async {
      final d = _Detector(() async => 'Qatar');
      final n = await _make(d, prefs: {'selected_country': 'Global'});
      expect(d.calls, 0);
      expect(_country(n), 'Global');
    });

    test(
      'a new session detects again (R8), a failure keeps the saved one',
      () async {
        final d = _Detector(() async => 'Qatar');
        await _make(d);
        expect(d.calls, 1);
        // Same device storage, a new launch, detection now fails.
        final failing = _Detector(() async => throw Exception('offline'));
        final again = SelectedLocationNotifier(detect: failing.call);
        await _settle(again);
        expect(failing.calls, 1);
        expect(_country(again), 'Qatar');
      },
    );
  });

  group('manual wins', () {
    test('a pick made while detection is running is kept', () async {
      final gate = Completer<String>();
      final d = _Detector(() => gate.future);
      SharedPreferences.setMockInitialValues({});
      final n = SelectedLocationNotifier(detect: d.call);
      await _settle(n);
      await n.setCountry('Morocco');
      gate.complete('Qatar');
      await _settle(n);
      expect(_country(n), 'Morocco');
      expect(await _saved(), 'Morocco');
    });

    test('a pick after a detection replaces it', () async {
      final n = await _make(_Detector(() async => 'Qatar'));
      expect(_country(n), 'Qatar');
      await n.setCountry('Egypt');
      expect(_country(n), 'Egypt');
      expect(await _saved(), 'Egypt');
    });
  });
}
