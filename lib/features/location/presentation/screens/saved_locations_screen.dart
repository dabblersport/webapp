import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/features/location/presentation/active_location_label.dart';
import 'package:dabbler/features/location/presentation/set_location_when_denied.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/location/data/device_location_store.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dabbler/features/location/presentation/widgets/save_location_sheet.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Settings > Location (KAN-589): the owner-private Saved places (Home, Work,
/// custom labels such as Gym). Tapping a place makes it this device's Manual
/// location. DS defaults (DabblerPage, titled top bar, DabblerSwipeAction rows,
/// a full-width add button in the page's bottom overlay). Public Profile
/// city/country is not managed here and is never touched from here.
class SavedLocationsScreen extends ConsumerWidget {
  const SavedLocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLocations = ref.watch(profileLocationNotifierProvider);
    final canPop = Navigator.of(context).canPop();

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: AppLocalizations.of(context).settings_tile_location,
        onBack: canPop ? () => Navigator.of(context).maybePop() : null,
      ),
      bottomOverlay: DabblerButton(
        label: AppLocalizations.of(context).location_add_place,
        icon: 'location-add',
        fullWidth: true,
        onPressed: () => _addLocation(context, ref),
      ),
      body: asyncLocations.when(
        loading: () => const Center(child: DabblerSpinner()),
        error: (e, _) => Center(
          child: DabblerEmptyState.error(
            title: AppLocalizations.of(context).location_saved_load_error,
          ),
        ),
        data: (locations) {
          if (locations.isEmpty) {
            return Column(
              children: [
                const _DeviceLocationSection(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(DabblerSpacing.space9),
                      child: DabblerEmptyState(
                        icon: 'location-slash',
                        title: AppLocalizations.of(
                          context,
                        ).location_saved_empty_title,
                        text: AppLocalizations.of(
                          context,
                        ).location_saved_empty_text,
                        size: DabblerEmptyStateSize.page,
                        action: DabblerButton(
                          label: AppLocalizations.of(
                            context,
                          ).location_saved_empty_cta,
                          icon: 'location-add',
                          onPressed: () => _addLocation(context, ref),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Primary pinned at top, rest sorted newest first (already from repo)
          final primary = locations.where((l) => l.isPrimary).toList();
          final rest = locations.where((l) => !l.isPrimary).toList();
          final sorted = [...primary, ...rest];

          return ListView.separated(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space5,
              DabblerSpacing.space5,
              DabblerSpacing.space5,
              DabblerSpacing.floatingBarClearance,
            ),
            itemCount: sorted.length + 2,
            separatorBuilder: (_, __) =>
                const DabblerGap.v(DabblerSpacing.space3),
            itemBuilder: (ctx, i) => i == 0
                ? const _DeviceLocationSection()
                : i == 1
                ? DabblerText(
                    AppLocalizations.of(ctx).location_saved_places,
                    style: DabblerType.headline,
                  )
                : _LocationTile(location: sorted[i - 2]),
          );
        },
      ),
    );
  }

  /// Starts from this device's current location (no GPS read and no
  /// permission request: the OS permission is asked once, elsewhere). With no
  /// point to start from, the manual "Set location" drawer opens instead. The
  /// sheet searches any place by name; no street address is asked for.
  Future<void> _addLocation(BuildContext context, WidgetRef ref) async {
    final active = ref.read(activeLocationProvider).valueOrNull;
    if (active is! ActiveLocationReady) {
      await showSetLocationDrawer(context);
      return;
    }
    final loc = active.location;
    final area = await ref.read(
      resolvedNearestAreaProvider((lat: loc.lat, lng: loc.lng)).future,
    );
    if (!context.mounted) return;
    if (area == null) {
      await showSetLocationDrawer(context);
      return;
    }
    await SaveLocationSheet.show(
      context,
      lat: loc.lat,
      lng: loc.lng,
      areaId: area.id,
      areaName: area.name,
    );
  }
}

// =============================================================================
// TILE
// =============================================================================

class _LocationTile extends ConsumerWidget {
  const _LocationTile({required this.location});
  final ProfileLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(profileLocationNotifierProvider.notifier);
    final selected = _isSelected(
      ref.watch(activeLocationProvider).valueOrNull,
      location,
    );

    // Was a Dismissible (end-to-start) with a confirm dialog; the DS swipe
    // reveals a Delete action that runs the same confirm, then deletes.
    return DabblerSwipeAction(
      key: ValueKey(location.id),
      actions: [
        DabblerSwipeActionItem(
          label: AppLocalizations.of(context).location_saved_delete,
          icon: 'trash',
          tone: DabblerSwipeActionTone.destructive,
          onPressed: () async {
            final confirmed = await _confirmDelete(context);
            if (confirmed == true) notifier.deleteLocation(location.id);
          },
        ),
      ],
      child: DabblerSurface(
        radius: DabblerRadius.card,
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space5,
          DabblerSpacing.space3,
          DabblerSpacing.space2,
          DabblerSpacing.space3,
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref
                    .read(activeLocationProvider.notifier)
                    .useSavedLocation(location),
                child: Semantics(
                  button: true,
                  selected: selected,
                  child: Row(
                    children: [
                      DabblerIconTile.named(
                        _labelIcon(location.label),
                        tone: location.isPrimary
                            ? DabblerIconTileTone.brand
                            : DabblerIconTileTone.info,
                      ),
                      const DabblerGap.h(DabblerSpacing.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: DabblerText(
                                    location.effectiveLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DabblerType.headline,
                                  ),
                                ),
                                if (location.isPrimary) ...[
                                  const DabblerGap.h(DabblerSpacing.space2),
                                  // The old badge text carried a star emoji; the star
                                  // is now a DabblerIcon (CEO rule: no emoji).
                                  DabblerBadge(
                                    label: AppLocalizations.of(
                                      context,
                                    ).primary_sport_badge,
                                    icon: DabblerIcon('star'),
                                  ),
                                ],
                              ],
                            ),
                            if (location.areaId != null)
                              _AreaName(areaId: location.areaId!),
                          ],
                        ),
                      ),
                      if (selected) const DabblerIcon('tick-circle'),
                    ],
                  ),
                ),
              ),
            ),
            // Star = set as primary
            if (!location.isPrimary)
              DabblerButton.icon(
                tone: DabblerButtonTone.text,
                icon: 'star',
                semanticLabel: AppLocalizations.of(
                  context,
                ).location_saved_set_primary,
                onPressed: () => notifier.setPrimary(location.id),
              ),
            // Rename
            DabblerButton.icon(
              tone: DabblerButtonTone.text,
              icon: 'edit',
              semanticLabel: AppLocalizations.of(context).location_saved_rename,
              onPressed: () => _rename(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDabblerDialog<bool>(
      context: context,
      builder: (ctx) => DabblerDialog(
        onClose: () => Navigator.pop(ctx, false),
        title: AppLocalizations.of(context).location_saved_delete_title,
        description: AppLocalizations.of(
          context,
        ).location_saved_delete_body(location.effectiveLabel),
        destructive: true,
        secondaryAction: DabblerDialogAction(
          label: AppLocalizations.of(context).home_location_cancel,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        primaryAction: DabblerDialogAction(
          label: AppLocalizations.of(context).location_saved_delete,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ),
    );
  }

  /// This place is the device's current selection: the selected saved place
  /// (by id), or the stored Manual point of this place after a restart.
  bool _isSelected(ActiveLocationState? s, ProfileLocation p) {
    if (s is! ActiveLocationReady) return false;
    final l = s.location;
    if (l.savedLocationId != null) return l.savedLocationId == p.id;
    return l.source == ActiveLocationSource.manual &&
        l.lat == p.lat &&
        l.lng == p.lng &&
        l.savedLocationLabel == p.effectiveLabel;
  }

  String _labelIcon(ProfileLocationLabel label) {
    switch (label) {
      case ProfileLocationLabel.home:
        return 'home-2';
      case ProfileLocationLabel.work:
        return 'briefcase';
      case ProfileLocationLabel.school:
        return 'teacher';
      case ProfileLocationLabel.current:
        return 'gps';
      case ProfileLocationLabel.custom:
        return 'location';
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    ProfileLocationLabel selectedLabel = location.label;
    final customController = TextEditingController(
      text: location.labelCustom ?? '',
    );

    final confirmed = await showDabblerDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => DabblerDialog(
          onClose: () => Navigator.pop(ctx, false),
          title: AppLocalizations.of(context).location_saved_rename_title,
          secondaryAction: DabblerDialogAction(
            label: AppLocalizations.of(context).home_location_cancel,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          primaryAction: DabblerDialogAction(
            label: AppLocalizations.of(context).game_prefs_save,
            onPressed: () => Navigator.pop(ctx, true),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: DabblerSpacing.space3,
                runSpacing: DabblerSpacing.space3,
                children: ProfileLocationLabel.values.map((l) {
                  return DabblerChip(
                    label: l.displayName,
                    selected: selectedLabel == l,
                    onTap: () => setState(() => selectedLabel = l),
                  );
                }).toList(),
              ),
              if (selectedLabel == ProfileLocationLabel.custom) ...[
                const DabblerGap.v(DabblerSpacing.space4),
                DabblerTextField(
                  controller: customController,
                  placeholder: AppLocalizations.of(
                    context,
                  ).location_saved_rename_hint,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final customName = customController.text.trim();
    if (confirmed == true &&
        selectedLabel == ProfileLocationLabel.custom &&
        customName.isEmpty) {
      if (context.mounted) {
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(
            message: AppLocalizations.of(context).location_custom_name_required,
          ),
        );
      }
      customController.dispose();
      return;
    }
    if (confirmed == true) {
      await ref
          .read(profileLocationNotifierProvider.notifier)
          .renameLocation(
            location.id,
            selectedLabel,
            customName: selectedLabel == ProfileLocationLabel.custom
                ? customController.text.trim()
                : null,
          );
    }
    customController.dispose();
  }
}

// =============================================================================
// AREA NAME RESOLVER
// =============================================================================

class _AreaName extends ConsumerWidget {
  const _AreaName({required this.areaId});
  final String areaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areaAsync = ref.watch(areaNameProvider(areaId));
    return areaAsync.maybeWhen(
      data: (name) => DabblerText(
        name,
        style: DabblerType.footnote,
        tone: DabblerTextTone.secondary,
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// The Manual/Auto mode this device holds; refreshes with the active location.
final _deviceModeProvider = FutureProvider.autoDispose<DeviceLocationMode?>((
  ref,
) async {
  ref.watch(activeLocationProvider);
  String? accountId;
  try {
    accountId = ref.watch(currentUserIdProvider);
  } catch (_) {
    accountId = null;
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    return DeviceLocationStore(prefs, accountId: accountId).read()?.mode;
  } catch (_) {
    return null;
  }
});

/// Location on this device (KAN-583): what this device is using now, Auto or
/// Manual, and the two ways to change it. A device with no city shows the
/// city-first "Set location" prompt as the only action. Per-device state only;
/// never the public Profile City/Country and never a saved place.
class _DeviceLocationSection extends ConsumerWidget {
  const _DeviceLocationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(activeLocationProvider).valueOrNull;
    final hasCity =
        state is ActiveLocationReady || state is ActiveLocationCityOnly;
    final mode = ref.watch(_deviceModeProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space5,
        end: DabblerSpacing.space5,
        top: DabblerSpacing.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DabblerText(
            l.location_settings_device_title,
            style: DabblerType.caption1,
          ),
          const DabblerGap.v(DabblerSpacing.space2),
          DabblerText(
            hasCity
                ? activeLocationLabel(l, state)
                : l.location_intro_select_city,
            style: DabblerType.headline,
          ),
          if (hasCity && mode != null)
            DabblerText(
              mode == DeviceLocationMode.auto
                  ? l.location_mode_auto
                  : l.location_mode_manual,
              style: DabblerType.caption1,
            ),
          const DabblerGap.v(DabblerSpacing.space3),
          if (hasCity)
            DabblerButton(
              label: l.location_use_current,
              tone: DabblerButtonTone.neutral,
              fullWidth: true,
              onPressed: () =>
                  ref.read(activeLocationProvider.notifier).useGpsLocation(),
            ),
          if (hasCity) const DabblerGap.v(DabblerSpacing.space3),
          DabblerButton(
            label: hasCity
                ? l.listing_set_location
                : l.location_intro_select_city,
            tone: hasCity
                ? DabblerButtonTone.neutral
                : DabblerButtonTone.primary,
            fullWidth: true,
            onPressed: () => showSetLocationDrawer(context),
          ),
        ],
      ),
    );
  }
}
