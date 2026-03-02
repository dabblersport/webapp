import 'dart:async';

import 'package:dabbler/data/models/place.dart';
import 'package:dabbler/features/places/providers/place_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A bottom sheet that lets the user search for and select a place (POI,
/// address, or city) via Mapbox Search — similar to Instagram/Threads
/// "Add location" flow.
///
/// Usage:
/// ```dart
/// final place = await PlacePickerSheet.show(context);
/// if (place != null) { /* attach to post */ }
/// ```
class PlacePickerSheet extends ConsumerStatefulWidget {
  const PlacePickerSheet({super.key});

  /// Show the picker and return the selected [Place], or `null` if dismissed.
  static Future<Place?> show(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PlacePickerSheet(),
    );
  }

  @override
  ConsumerState<PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends ConsumerState<PlacePickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Place> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── Search logic ───────────────────────────────────────────────────────

  void _onQueryChanged(String query) {
    _debounce?.cancel();

    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(query.trim());
    });
  }

  Future<void> _search(String query) async {
    final repo = ref.read(placeRepositoryProvider);
    final result = await repo.searchPlaces(query: query);

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _loading = false;
      }),
      (places) => setState(() {
        _results = places;
        _error = null;
        _loading = false;
      }),
    );
  }

  // ── Selection ──────────────────────────────────────────────────────────

  Future<void> _onPlaceSelected(Place place) async {
    // Show a brief loading indicator on the tile.
    setState(() => _loading = true);

    final repo = ref.read(placeRepositoryProvider);
    final result = await repo.resolvePlace(mapboxId: place.id);

    if (!mounted) return;

    result.fold(
      // Fall back to the partial suggestion data on failure.
      (_) => Navigator.of(context).pop(place),
      (resolved) => Navigator.of(context).pop(resolved),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Handle ──
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Add Location',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),

            // ── Search field ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                autofocus: true,
                style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search places...',
                  hintStyle: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: cs.onSurfaceVariant),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // ── Results ──
            if (_loading && _results.isEmpty)
              const Expanded(
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: tt.bodyMedium?.copyWith(color: cs.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else if (_results.isEmpty && _controller.text.trim().length >= 2)
              Expanded(
                child: Center(
                  child: Text(
                    'No places found',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _results.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (context, index) {
                    final place = _results[index];
                    return _PlaceTile(
                      place: place,
                      onTap: () => _onPlaceSelected(place),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Place tile
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, required this.onTap});

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.location_on_outlined, color: cs.primary, size: 22),
      ),
      title: Text(
        place.name,
        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: place.fullAddress != null
          ? Text(
              place.fullAddress!,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
