import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/services/recent_places_service.dart';
import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
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

  RecentPlace toRecent() =>
      RecentPlace(name: name, venueId: venueId, lat: lat, lng: lng);

  static ComposerPlacePick fromRecent(RecentPlace r) => ComposerPlacePick(
    name: r.name,
    venueId: r.venueId,
    lat: r.lat,
    lng: r.lng,
  );
}

/// Opens "Add location" (`Home Feed.dc.html:818-875`): a search field, "Use
/// current location" and the Recent group until something is typed, then the
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
  final confirm = ComposerSheetConfirm(
    label: l.composer_confirm,
    onTap: () {
      final pick = pending.value;
      if (pick != null) {
        // KAN-469: remember the confirmed place for this user's Recent group.
        const RecentPlacesService().add(
          ref.read(currentUserIdProvider),
          pick.toRecent(),
        );
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
  );
  // Content-sized, capped at the frame's 74% (`Home Feed.dc.html:818`,
  // `sheetP74`).
  return showDabblerSheet<void>(
    context: context,
    title: l.composer_add_location,
    titleWidget: composerSheetTitle(l.composer_add_location),
    detent: DabblerSheetDetent.content,
    contentMaxFraction: DabblerSheet.contentMaxFractionMedium,
    pageBackground: true,
    hairlineOutside: ComposerFrameScope.active(context),
    showCloseButton: false,
    headerActionBuilder: (ctx) => composerSheetHeaderActions(
      context,
      ctx,
      onClear: notifier.clearLocation,
    ),
    footerBuilder: (_) => composerSheetFooter(confirm),
    builder: composerFrameBuilder(
      context,
      (_) => ComposerPlaceSheet(pending: pending),
    ),
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
  bool _locating = false;
  bool _locationDenied = false;
  late final Future<List<RecentPlace>> _recents = const RecentPlacesService()
      .read(ref.read(currentUserIdProvider));

  /// "Use current location": tags the post with the device position through
  /// [PostComposerNotifier.useCurrentLocation], then closes the sheet as a
  /// confirmed pick does; when the location is unavailable it changes
  /// nothing and shows the inline message instead.
  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _locating = true;
      _locationDenied = false;
    });
    final outcome = await ref
        .read(postComposerProvider.notifier)
        .useCurrentLocation(fallbackName: l.composer_place_current_location);
    if (!mounted) return;
    if (outcome == ComposerLocateOutcome.unavailable) {
      setState(() {
        _locating = false;
        _locationDenied = true;
      });
      return;
    }
    final s = ref.read(postComposerProvider);
    widget.pending.value = ComposerPlacePick(
      name: s.locationName ?? l.composer_place_current_location,
      lat: s.geoLat,
      lng: s.geoLng,
    );
    setState(() => _locating = false);
    Navigator.of(context).maybePop();
  }

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
        // Before anything is typed (`Home Feed.dc.html:836-849`, `placesFor`
        // at ~2979): "Use current location", then the "Recent" group.
        if (typed.isEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: DabblerSpacing.space3,
            ),
            child: ComposerPickerRow(
              key: const Key('composer-place-use-current'),
              icon: 'gps',
              accent: true,
              title: l.home_location_use_current,
              onTap: _useCurrentLocation,
            ),
          ),
          if (_locationDenied)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: DabblerSpacing.space2,
              ),
              child: DabblerText(
                l.composer_place_location_denied,
                key: const Key('composer-place-location-denied'),
                style: DabblerType.caption1,
                tone: DabblerTextTone.secondary,
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: DabblerSpacing.space5,
              bottom: DabblerSpacing.space2,
            ),
            child: DabblerText(
              l.home_location_recent,
              style: DabblerType.caption1,
              tone: DabblerTextTone.secondary,
            ),
          ),
          // KAN-469: this user's confirmed places, newest first; the empty
          // state until one has been confirmed.
          FutureBuilder<List<RecentPlace>>(
            future: _recents,
            builder: (context, snap) {
              final recents = snap.data ?? const <RecentPlace>[];
              if (recents.isEmpty) {
                return ComposerCenteredState.message(
                  l.composer_place_recent_empty,
                  key: const Key('composer-place-recent-empty'),
                );
              }
              return ValueListenableBuilder<ComposerPlacePick?>(
                valueListenable: widget.pending,
                builder: (context, current, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in recents)
                      ComposerPickerRow(
                        key: ValueKey('composer-place-recent-${r.identity}'),
                        icon: 'location',
                        title: r.name,
                        selected: current?.toRecent().identity == r.identity,
                        onTap: () => widget.pending.value =
                            ComposerPlacePick.fromRecent(r),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
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
