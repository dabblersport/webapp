import 'package:dabbler/data/models/place.dart';
import 'package:dabbler/data/repositories/place_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Repository ──────────────────────────────────────────────────────────────

final placeRepositoryProvider = Provider<PlaceRepository>((ref) {
  return PlaceRepository();
});

// ─── Selected place for post creation ────────────────────────────────────────

/// Holds the currently selected [Place] during post creation.
/// Reset to `null` when navigating away from the create-post screen.
final selectedPlaceProvider = StateProvider<Place?>((ref) => null);
