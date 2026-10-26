import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/profile_location_repository.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-589 round E: in the real app, a user who opened Location settings
/// without first visiting a profile screen could not save any place. The
/// profile controller is loaded only by the profile screens, so its profile id
/// was null and the save failed before any write ("Couldn't save this
/// location"). Earlier tests always seeded the profile controller, which is
/// why they never saw it. These tests leave it empty, as the app does.

class _EmptyProfile extends StateNotifier<ProfileState>
    implements ProfileController {
  _EmptyProfile() : super(const ProfileState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements ProfileLocationRepository {
  final List<String> calls = [];

  @override
  Future<Result<List<ProfileLocation>, Failure>> getLocations() async =>
      const Ok(<ProfileLocation>[]);

  @override
  Future<Result<String, Failure>> resolveGeoLocationId({
    required double lat,
    required double lng,
    required String areaId,
  }) async {
    calls.add('geo');
    return const Ok('geo-1');
  }

  @override
  Future<Result<ProfileLocation, Failure>> saveLocation({
    required String profileId,
    required double lat,
    required double lng,
    required String geoLocationId,
    required String areaId,
    required ProfileLocationLabel label,
    String? labelCustom,
    bool isPrimary = false,
  }) async {
    calls.add('save:$profileId');
    return Ok(
      ProfileLocation(
        id: 'pl-1',
        profileId: profileId,
        areaId: areaId,
        lat: lat,
        lng: lng,
        label: label,
        isPrimary: isPrimary,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<Result<void, Failure>> setPrimary(
    String locationId, {
    required double lat,
    required double lng,
    required String profileId,
  }) async {
    calls.add('primary:$profileId');
    return const Ok(null);
  }

  @override
  Future<Result<void, Failure>> deleteLocation(String locationId) async =>
      const Ok(null);

  @override
  Future<Result<void, Failure>> renameLocation(
    String locationId,
    ProfileLocationLabel label, {
    String? customName,
  }) async => const Ok(null);

  @override
  Future<Result<void, Failure>> updateRadius(
    String locationId,
    int meters,
  ) async => const Ok(null);
}

ProviderContainer _container(_Repo repo, {String? activeProfileId}) {
  final c = ProviderContainer(
    overrides: [
      profileLocationRepositoryProvider.overrideWithValue(repo),
      profileControllerProvider.overrideWith((ref) => _EmptyProfile()),
      myProfileIdProvider.overrideWith((ref) async => activeProfileId),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('a place saves when the profile screen was never opened', () async {
    final repo = _Repo();
    final c = _container(repo, activeProfileId: 'p-active');
    await c.read(profileLocationNotifierProvider.future);

    final outcome = await c
        .read(profileLocationNotifierProvider.notifier)
        .savePlace(
          lat: 25.1972,
          lng: 55.2744,
          areaId: 'area-zabeel',
          label: ProfileLocationLabel.school,
        );

    expect(outcome, SavePlaceOutcome.saved);
    expect(repo.calls, ['geo', 'save:p-active']);
    expect(c.read(profileLocationNotifierProvider).value, hasLength(1));
  });

  test('a saved place becomes primary without the profile screen', () async {
    final repo = _Repo();
    final c = _container(repo, activeProfileId: 'p-active');
    await c.read(profileLocationNotifierProvider.future);
    final notifier = c.read(profileLocationNotifierProvider.notifier);
    await notifier.savePlace(
      lat: 25.1972,
      lng: 55.2744,
      areaId: 'area-zabeel',
      label: ProfileLocationLabel.school,
    );

    await notifier.setPrimary('pl-1');

    expect(repo.calls.last, 'primary:p-active');
    expect(
      c.read(profileLocationNotifierProvider).value!.single.isPrimary,
      isTrue,
    );
  });

  test('with no signed-in profile at all, nothing is written', () async {
    final repo = _Repo();
    final c = _container(repo);
    await c.read(profileLocationNotifierProvider.future);

    final outcome = await c
        .read(profileLocationNotifierProvider.notifier)
        .savePlace(
          lat: 25.1972,
          lng: 55.2744,
          areaId: 'area-zabeel',
          label: ProfileLocationLabel.school,
        );

    expect(outcome, SavePlaceOutcome.failed);
    expect(repo.calls, isEmpty);
  });
}
