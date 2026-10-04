import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// A place chosen in [showComposerPlaceSheet]: a venue (with [venueId]) or a
/// typed location.
class ComposerPlacePick {
  const ComposerPlacePick({
    required this.name,
    this.venueId,
    this.lat,
    this.lng,
  });

  final String name;
  final String? venueId;
  final double? lat;
  final double? lng;
}

/// Opens "Add location" (`Home Feed.dc.html:818-875`): a search field, the
/// matching places, a Clear action and a `Confirm` footer that applies the
/// pending place.
Future<void> showComposerPlaceSheet(BuildContext context, WidgetRef ref) {
  final state = ref.read(postComposerProvider);
  final notifier = ref.read(postComposerProvider.notifier);
  final pending = ValueNotifier<ComposerPlacePick?>(
    state.locationName == null
        ? null
        : ComposerPlacePick(
            name: state.locationName!,
            venueId: state.venueId,
            lat: state.geoLat,
            lng: state.geoLng,
          ),
  );
  final l = AppLocalizations.of(context);
  return showComposerSheet<void>(
    context,
    title: l.composer_add_location,
    onClear: state.locationName == null ? null : notifier.clearLocation,
    confirm: ComposerSheetConfirm(
      label: l.composer_confirm,
      onTap: () {
        final pick = pending.value;
        if (pick != null) {
          if (pick.venueId != null) {
            notifier.setVenue(
              id: pick.venueId!,
              name: pick.name,
              lat: pick.lat,
              lng: pick.lng,
            );
          } else {
            notifier.setRawLocation(name: pick.name);
          }
        }
        Navigator.of(context).maybePop();
      },
    ),
    builder: (_) => ComposerPlaceSheet(pending: pending),
  );
}

/// The search field and place rows of [showComposerPlaceSheet].
class ComposerPlaceSheet extends ConsumerStatefulWidget {
  const ComposerPlaceSheet({super.key, required this.pending});

  final ValueNotifier<ComposerPlacePick?> pending;

  @override
  ConsumerState<ComposerPlaceSheet> createState() => _ComposerPlaceSheetState();
}

class _ComposerPlaceSheetState extends ConsumerState<ComposerPlaceSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final typed = _query.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComposerSearchField(
          controller: _search,
          placeholder: l.composer_place_search,
          onChanged: (v) => setState(() => _query = v),
        ),
        if (typed.length >= 2)
          ValueListenableBuilder<ComposerPlacePick?>(
            valueListenable: widget.pending,
            builder: (context, current, _) => Consumer(
              builder: (context, ref, _) {
                final venues = ref.watch(venueSearchProvider(typed));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: DabblerSpacing.space5,
                        bottom: DabblerSpacing.space2,
                      ),
                      child: DabblerText(
                        l.composer_results,
                        style: DabblerType.caption1,
                        tone: DabblerTextTone.secondary,
                      ),
                    ),
                    ...venues.when(
                      loading: () => const [ComposerCenteredState.loading()],
                      error: (_, __) => [
                        ComposerCenteredState.message(l.composer_search_failed),
                      ],
                      data: (rows) => [
                        for (final venue in rows)
                          ComposerPickerRow(
                            icon: 'location',
                            title: venue['name'] as String? ?? l.composer_venue,
                            subtitle: venue['city'] as String?,
                            selected: current?.venueId == venue['id'],
                            onTap: () =>
                                widget.pending.value = ComposerPlacePick(
                                  name:
                                      venue['name'] as String? ??
                                      l.composer_venue,
                                  venueId: venue['id'] as String,
                                  lat: venue['geo_lat'] as double?,
                                  lng: venue['geo_lng'] as double?,
                                ),
                          ),
                        if (rows.isEmpty)
                          ComposerCenteredState.message(l.composer_places_none),
                      ],
                    ),
                    ComposerPickerRow(
                      icon: 'location-add',
                      title: l.composer_use_typed(typed),
                      selected:
                          current != null &&
                          current.venueId == null &&
                          current.name == typed,
                      onTap: () =>
                          widget.pending.value = ComposerPlacePick(name: typed),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
