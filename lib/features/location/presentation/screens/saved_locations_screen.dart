import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/features/location/presentation/add_saved_place.dart';
import 'package:dabbler/features/location/presentation/device_location_section.dart';
import 'package:dabbler/features/location/presentation/saved_place_labels.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
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
    final l10n = AppLocalizations.of(context);

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: l10n.settings_tile_location,
        onBack: canPop ? () => Navigator.of(context).maybePop() : null,
      ),
      bottomOverlay: DabblerButton(
        label: l10n.location_add_place,
        icon: 'location-add',
        fullWidth: true,
        onPressed: () => startAddSavedPlace(context, ref),
      ),
      body: asyncLocations.when(
        loading: () => const Center(child: DabblerSpinner()),
        error: (e, _) => Center(
          child: DabblerEmptyState.error(title: l10n.saved_places_load_error),
        ),
        data: (locations) {
          // Primary pinned at top, rest sorted newest first (already from repo)
          final primary = locations.where((l) => l.isPrimary).toList();
          final rest = locations.where((l) => !l.isPrimary).toList();
          final sorted = [...primary, ...rest];

          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space5,
              DabblerSpacing.space5,
              DabblerSpacing.space5,
              DabblerSpacing.floatingBarClearance,
            ),
            children: [
              DabblerText(
                l10n.location_page_private,
                style: DabblerType.footnote,
                tone: DabblerTextTone.secondary,
              ),
              const DabblerGap.v(DabblerSpacing.space5),
              const DeviceLocationSection(),
              const DabblerGap.v(DabblerSpacing.space6),
              DabblerText(
                l10n.location_saved_places_header,
                style: DabblerType.headline,
              ),
              const DabblerGap.v(DabblerSpacing.space2),
              DabblerText(
                l10n.location_saved_places_note,
                style: DabblerType.footnote,
                tone: DabblerTextTone.secondary,
              ),
              if (sorted.isEmpty) ...[
                const DabblerGap.v(DabblerSpacing.space4),
                DabblerEmptyState(
                  icon: 'location-slash',
                  title: l10n.saved_places_empty_title,
                  text: l10n.saved_places_empty_text,
                  size: DabblerEmptyStateSize.page,
                  action: DabblerButton(
                    label: l10n.saved_places_add_first,
                    icon: 'location-add',
                    onPressed: () => startAddSavedPlace(context, ref),
                  ),
                ),
              ] else ...[
                for (final place in sorted) ...[
                  const DabblerGap.v(DabblerSpacing.space3),
                  _LocationTile(location: place),
                ],
              ],
            ],
          );
        },
      ),
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
          label: AppLocalizations.of(context).saved_places_delete,
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
                ).saved_places_set_primary,
                onPressed: () => notifier.setPrimary(location.id),
              ),
            // Rename
            DabblerButton.icon(
              tone: DabblerButtonTone.text,
              icon: 'edit',
              semanticLabel: AppLocalizations.of(context).saved_places_rename,
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
        title: AppLocalizations.of(context).saved_places_delete_title,
        description: AppLocalizations.of(
          context,
        ).saved_places_delete_body(location.effectiveLabel),
        destructive: true,
        secondaryAction: DabblerDialogAction(
          label: AppLocalizations.of(context).home_location_cancel,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        primaryAction: DabblerDialogAction(
          label: AppLocalizations.of(context).saved_places_delete,
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
          title: AppLocalizations.of(context).saved_places_rename_title,
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
                    label: savedPlaceLabelName(AppLocalizations.of(context), l),
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
                  ).saved_places_custom_name,
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
