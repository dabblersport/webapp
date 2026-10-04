import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/features/location/presentation/widgets/save_location_sheet.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';

/// Saved locations. No design frame: DS defaults (DabblerPage, titled top
/// bar, DabblerSwipeAction rows, a full-width add button in the page's bottom
/// overlay in place of the extended FAB). The wide-screen shell
/// wrapper is dropped as in the earlier waves; the app shell owns navigation.
class SavedLocationsScreen extends ConsumerWidget {
  const SavedLocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLocations = ref.watch(profileLocationNotifierProvider);
    final canPop = Navigator.of(context).canPop();

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Saved Locations',
        onBack: canPop ? () => Navigator.of(context).maybePop() : null,
      ),
      bottomOverlay: DabblerButton(
        label: 'Add location',
        icon: 'location-add',
        fullWidth: true,
        onPressed: () => _addLocation(context, ref),
      ),
      body: asyncLocations.when(
        loading: () => const Center(child: DabblerSpinner()),
        error: (e, _) => const Center(
          child: DabblerEmptyState.error(title: 'Could not load locations'),
        ),
        data: (locations) {
          if (locations.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DabblerSpacing.space9),
                child: DabblerEmptyState(
                  icon: 'location-slash',
                  title: 'No saved locations yet',
                  text:
                      'Save your home, work, or favourite spots so you can '
                      'quickly tag them in posts.',
                  size: DabblerEmptyStateSize.page,
                  action: DabblerButton(
                    label: 'Add your first location',
                    icon: 'location-add',
                    onPressed: () => _addLocation(context, ref),
                  ),
                ),
              ),
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
            itemCount: sorted.length,
            separatorBuilder: (_, __) =>
                const DabblerGap.v(DabblerSpacing.space3),
            itemBuilder: (ctx, i) => _LocationTile(location: sorted[i]),
          );
        },
      ),
    );
  }

  Future<void> _addLocation(BuildContext context, WidgetRef ref) async {
    final gps = ref.read(gpsServiceProvider);
    final result = await gps.getCurrentLocation();

    if (!context.mounted) return;

    void toast(String message) => DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message));

    switch (result) {
      case LocationDenied():
        toast('Location permission denied');
        return;
      case LocationDeniedForever():
        toast('Enable location in Settings to continue');
        await Geolocator.openAppSettings();
        return;
      case LocationServiceOff():
        toast('Please enable location services');
        return;
      case LocationTimeout():
        toast('Could not get location — try again');
        return;
      case LocationError(:final message):
        toast('Location error: $message');
        return;
      case LocationSuccess(:final lat, :final lng, :final accuracyMeters):
        // Resolve nearest area
        final area = await ref.read(
          resolvedNearestAreaProvider((lat: lat, lng: lng)).future,
        );
        if (!context.mounted) return;
        if (area == null) {
          toast('Could not resolve area');
          return;
        }
        await SaveLocationSheet.show(
          context,
          lat: lat,
          lng: lng,
          areaId: area.id,
          areaName: area.name,
          accuracyMeters: accuracyMeters,
        );
    }
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

    // Was a Dismissible (end-to-start) with a confirm dialog; the DS swipe
    // reveals a Delete action that runs the same confirm, then deletes.
    return DabblerSwipeAction(
      key: ValueKey(location.id),
      actions: [
        DabblerSwipeActionItem(
          label: 'Delete',
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
                        const DabblerBadge(
                          label: 'Primary',
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
            // Star = set as primary
            if (!location.isPrimary)
              DabblerButton.icon(
                tone: DabblerButtonTone.text,
                icon: 'star',
                semanticLabel: 'Set as primary',
                onPressed: () => notifier.setPrimary(location.id),
              ),
            // Rename
            DabblerButton.icon(
              tone: DabblerButtonTone.text,
              icon: 'edit',
              semanticLabel: 'Rename',
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
        title: 'Delete location?',
        description:
            'Remove "${location.effectiveLabel}" from your saved locations?',
        destructive: true,
        secondaryAction: DabblerDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(ctx, false),
        ),
        primaryAction: DabblerDialogAction(
          label: 'Delete',
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ),
    );
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
          title: 'Rename location',
          secondaryAction: DabblerDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          primaryAction: DabblerDialogAction(
            label: 'Save',
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
                  placeholder: 'Custom name',
                ),
              ],
            ],
          ),
        ),
      ),
    );

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
