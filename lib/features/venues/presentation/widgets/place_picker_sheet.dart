import 'dart:async';

import 'package:dabbler/data/models/place.dart';
import 'package:dabbler/features/location/presentation/widgets/autofocus_search_field.dart';
import 'package:dabbler/features/location/presentation/widgets/location_picker_row.dart';
import 'package:dabbler/features/venues/presentation/providers/place_providers.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
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
    // Was showAdaptiveSheet + DraggableScrollableSheet (0.75, 0.5-0.95).
    return showDabblerSheet<Place>(
      context: context,
      detents: const <double>[0.75, 0.95],
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
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);

    // The DabblerSheet body is already a scroll view, so this shrink-wraps.
    const pad = EdgeInsets.all(DabblerSpacing.space8);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Title ── (handle and close come from DabblerSheet)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            DabblerSpacing.space5,
            0,
            DabblerSpacing.space5,
            DabblerSpacing.space3,
          ),
          child: Text(
            'Add Location',
            style: DabblerType.headline
                .resolveForDirection(direction)
                .copyWith(color: colors.textPrimary),
          ),
        ),

        // ── Search field ──
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DabblerSpacing.space5,
            vertical: DabblerSpacing.space3,
          ),
          child: AutofocusSearchField(
            controller: _controller,
            placeholder: 'Search places...',
            onChanged: _onQueryChanged,
          ),
        ),

        // ── Results ──
        if (_loading && _results.isEmpty)
          const Padding(
            padding: pad,
            child: Center(child: DabblerSpinner()),
          )
        else if (_error != null)
          Padding(
            padding: pad,
            child: DabblerEmptyState.error(
              title: _error!,
              size: DabblerEmptyStateSize.inline,
            ),
          )
        else if (_results.isEmpty && _controller.text.trim().length >= 2)
          const Padding(
            padding: pad,
            child: DabblerEmptyState(icon: 'location', text: 'No places found'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DabblerSpacing.space5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final place in _results)
                  PickerRow(
                    leading: const DabblerIconTile.named('location'),
                    title: place.name,
                    subtitle: place.fullAddress,
                    onTap: () => _onPlaceSelected(place),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
