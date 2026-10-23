import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/venues/experiment/places_ui_kit_experiment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host implements PlacesUiKitHost {
  int builds = 0;
  Widget? result = const SizedBox(key: ValueKey('google'));

  @override
  Widget? buildCover(String placeId, {required double height}) {
    builds++;
    return result;
  }
}

const _baseline = SizedBox(key: ValueKey('baseline'));
const _id = 'b53aea46-f61e-4d81-9de7-9ca515f0b9f9';

Widget _cover({
  String id = _id,
  bool enabled = true,
  TargetPlatform platform = TargetPlatform.android,
  bool isWeb = false,
}) => experimentCover(
  venueId: id,
  baseline: _baseline,
  height: 170,
  enabled: enabled,
  platform: platform,
  isWeb: isWeb,
);

void main() {
  late _Host host;

  setUp(() {
    PlacesExperiment.reset();
    host = _Host();
    PlacesExperiment.host = host;
    PlacesExperiment.manifest = {_id: 'ChIJ-test-place-id'};
  });

  tearDown(PlacesExperiment.reset);

  test('the flag is off by default', () {
    expect(FeatureFlags.placesUiKitExperiment, isFalse);
  });

  test('flag off: baseline, host never called, nothing counted', () {
    final w = experimentCover(
      venueId: _id,
      baseline: _baseline,
      height: 170,
      platform: TargetPlatform.android,
      isWeb: false,
    );
    expect(identical(w, _baseline), isTrue);
    expect(host.builds, 0);
    expect(PlacesExperiment.guard.used, 0);
  });

  test('allowlist is the nine canonical ids', () {
    expect(kPlacesExperimentVenues, hasLength(9));
    expect(kPlacesExperimentVenues.map((v) => v.venueId).toSet(), hasLength(9));
    // The Champs UAE duplicate is identity research only.
    expect(
      PlacesExperiment.isAllowlisted('4b83429f-2076-421d-a9ca-4313bcee1a6a'),
      isFalse,
    );
  });

  test('flag on and everything present: the host cover', () {
    final w = _cover();
    expect((w.key as ValueKey).value, 'google');
    expect(host.builds, 1);
  });

  test('web and desktop keep the baseline', () {
    expect(identical(_cover(isWeb: true), _baseline), isTrue);
    expect(
      identical(_cover(platform: TargetPlatform.macOS), _baseline),
      isTrue,
    );
    expect(host.builds, 0);
  });

  test('an id outside the nine keeps the baseline', () {
    expect(identical(_cover(id: 'not-allowlisted'), _baseline), isTrue);
    expect(host.builds, 0);
  });

  test('unmatched venue (no confirmed Place ID) keeps the baseline', () {
    PlacesExperiment.manifest = {};
    expect(identical(_cover(), _baseline), isTrue);
    expect(host.builds, 0);
  });

  test('no native host registered keeps the baseline', () {
    PlacesExperiment.host = null;
    expect(identical(_cover(), _baseline), isTrue);
  });

  test('a host that cannot show the place falls back', () {
    host.result = null;
    expect(identical(_cover(), _baseline), isTrue);
  });

  test('a spent budget falls back and counts nothing more', () {
    PlacesExperiment.guard = PlacesAttemptGuard(ceiling: 2, used: 2);
    expect(identical(_cover(), _baseline), isTrue);
    expect(host.builds, 0);
    expect(PlacesExperiment.guard.used, 2);
  });

  test('the guard stops at the ceiling', () {
    final g = PlacesAttemptGuard(ceiling: 3);
    expect(
      [g.tryReserve(), g.tryReserve(), g.tryReserve(), g.tryReserve()],
      [true, true, true, false],
    );
    expect(g.used, 3);
    expect(g.remaining, 0);
    expect(kPlacesAttemptCeiling, 2000);
  });
}
