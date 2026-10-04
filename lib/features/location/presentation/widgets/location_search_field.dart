import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/providers/mapbox_geocode_provider.dart';

/// Reusable Mapbox-powered location search field with dropdown overlay.
class LocationSearchField extends ConsumerStatefulWidget {
  const LocationSearchField({
    super.key,
    required this.onSelected,
    this.initialQuery = '',
    this.hintText = 'Search for a place\u2026',
    this.proximity,
    this.autofocus = false,
  });

  final void Function(MapboxPlace place) onSelected;
  final String initialQuery;
  final String hintText;
  final LatLng? proximity;
  final bool autofocus;

  @override
  ConsumerState<LocationSearchField> createState() =>
      _LocationSearchFieldState();
}

class _LocationSearchFieldState extends ConsumerState<LocationSearchField> {
  late final TextEditingController _controller;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();

  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _query = widget.initialQuery;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay removal so tap on overlay item registers first.
      Future.delayed(DabblerMotion.delaySettle, _removeOverlay);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.length < 2) {
      setState(() => _query = '');
      _removeOverlay();
      return;
    }

    _debounce = Timer(DabblerMotion.debounceSearch, () {
      if (!mounted) return;
      setState(() => _query = trimmed);
      _showOverlay();
    });
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _buildOverlay();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectPlace(MapboxPlace place) {
    _controller.text = place.name;
    _removeOverlay();
    _focusNode.unfocus();
    widget.onSelected(place);
  }

  OverlayEntry _buildOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (_) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: TapRegion(
            onTapOutside: (_) => _removeOverlay(),
            child: _ResultsDropdown(query: _query, onSelected: _selectPlace),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The in-field spinner while the geocode request for the current query
    // (two characters or more) is in flight, as the old field drew it.
    final searching =
        _query.length >= 2 &&
        ref.watch(mapboxGeocodeProvider(_query)).isLoading;
    return CompositedTransformTarget(
      link: _layerLink,
      child: DabblerSearchField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        loading: searching,
        onChanged: _onChanged,
        onCleared: () => _onChanged(''),
        placeholder: widget.hintText,
      ),
    );
  }
}

// =============================================================================
// RESULTS DROPDOWN
// =============================================================================

class _ResultsDropdown extends ConsumerWidget {
  const _ResultsDropdown({required this.query, required this.onSelected});

  final String query;
  final void Function(MapboxPlace) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mapboxGeocodeProvider(query));

    return DabblerSurface(
      radius: DabblerRadius.lg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(DabblerSpacing.space5),
            child: Center(child: DabblerSpinner(size: DabblerSpinnerSize.sm)),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(DabblerSpacing.space5),
            child: DabblerText(
              'Couldn’t load results',
              style: DabblerType.subheadline,
              tone: DabblerTextTone.secondary,
            ),
          ),
          data: (places) {
            if (places.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(DabblerSpacing.space5),
                child: DabblerText(
                  'No results found',
                  style: DabblerType.subheadline,
                  tone: DabblerTextTone.secondary,
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                vertical: DabblerSpacing.space1,
              ),
              itemCount: places.length,
              separatorBuilder: (_, __) =>
                  const DabblerDivider(inset: DabblerSpacing.space5),
              itemBuilder: (_, i) {
                final place = places[i];
                return DabblerInputRow(
                  flat: true,
                  title: place.name,
                  subtitle: place.fullAddress,
                  onTap: () => onSelected(place),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
