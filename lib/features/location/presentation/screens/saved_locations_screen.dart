import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:dabbler/widgets/adaptive_scaffold.dart';
import 'package:dabbler/core/constants/adaptive_destinations.dart';
import 'package:dabbler/core/services/gps_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/features/location/presentation/widgets/save_location_sheet.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';

class SavedLocationsScreen extends ConsumerWidget {
  const SavedLocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final asyncLocations = ref.watch(profileLocationNotifierProvider);

    final content = Scaffold(
      appBar: AppBar(
        title: const Text('Saved Locations'),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addLocation(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add location'),
      ),
      body: asyncLocations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Could not load locations',
            style: tt.bodyMedium?.copyWith(color: cs.error),
          ),
        ),
        data: (locations) {
          if (locations.isEmpty) {
            return _EmptyState(onAdd: () => _addLocation(context, ref));
          }

          // Primary pinned at top, rest sorted newest first (already from repo)
          final primary = locations.where((l) => l.isPrimary).toList();
          final rest = locations.where((l) => !l.isPrimary).toList();
          final sorted = [...primary, ...rest];

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _LocationTile(location: sorted[i]),
          );
        },
      ),
    );

    if (MediaQuery.of(context).size.width >= AdaptiveBreakpoints.compact) {
      return AdaptiveScaffold(
        currentIndex: 6,
        destinations: kAdaptiveDestinations,
        onDestinationSelected: (i) =>
            onAdaptiveDestinationSelected(context, i, activeIndex: 6),
        headerWidget: SvgPicture.asset(
          'assets/images/dabbler_text_logo.svg',
          width: 100,
          height: 18,
          colorFilter: ColorFilter.mode(cs.onSurface, BlendMode.srcIn),
        ),
        body: content,
      );
    }
    return content;
  }

  Future<void> _addLocation(BuildContext context, WidgetRef ref) async {
    final gps = ref.read(gpsServiceProvider);
    final result = await gps.getCurrentLocation();

    if (!context.mounted) return;

    switch (result) {
      case LocationDenied():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      case LocationDeniedForever():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable location in Settings to continue'),
          ),
        );
        await Geolocator.openAppSettings();
        return;
      case LocationServiceOff():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        return;
      case LocationTimeout():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get location — try again')),
        );
        return;
      case LocationError(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $message')),
        );
        return;
      case LocationSuccess(:final lat, :final lng, :final accuracyMeters):
        // Resolve nearest area
        final area = await ref.read(
          resolvedNearestAreaProvider((lat: lat, lng: lng)).future,
        );
        if (!context.mounted) return;
        if (area == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not resolve area')),
          );
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final notifier = ref.read(profileLocationNotifierProvider.notifier);

    return Dismissible(
      key: ValueKey(location.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete location?'),
          content:
              Text('Remove "${location.effectiveLabel}" from your saved locations?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: cs.error),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      onDismissed: (_) => notifier.deleteLocation(location.id),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: location.isPrimary
                ? cs.primaryContainer
                : cs.surfaceContainerHigh,
            child: Icon(
              _labelIcon(location.label),
              size: 20,
              color: location.isPrimary ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
          title: Row(
            children: [
              Text(
                location.effectiveLabel,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (location.isPrimary) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⭐ Primary',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: location.areaId != null
              ? _AreaName(areaId: location.areaId!)
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Star = set as primary
              if (!location.isPrimary)
                IconButton(
                  icon: const Icon(Icons.star_outline),
                  tooltip: 'Set as primary',
                  onPressed: () => notifier.setPrimary(location.id),
                ),
              // Rename
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Rename',
                onPressed: () => _rename(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _labelIcon(ProfileLocationLabel label) {
    switch (label) {
      case ProfileLocationLabel.home:
        return Icons.home_outlined;
      case ProfileLocationLabel.work:
        return Icons.work_outline;
      case ProfileLocationLabel.school:
        return Icons.school_outlined;
      case ProfileLocationLabel.current:
        return Icons.my_location_outlined;
      case ProfileLocationLabel.custom:
        return Icons.place_outlined;
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    ProfileLocationLabel selectedLabel = location.label;
    final customController =
        TextEditingController(text: location.labelCustom ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Rename location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ProfileLocationLabel.values.map((l) {
                  return ChoiceChip(
                    label: Text(l.displayName),
                    selected: selectedLabel == l,
                    onSelected: (_) => setState(() => selectedLabel = l),
                  );
                }).toList(),
              ),
              if (selectedLabel == ProfileLocationLabel.custom) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: customController,
                  decoration: const InputDecoration(
                    hintText: 'Custom name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await ref.read(profileLocationNotifierProvider.notifier).renameLocation(
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final areaAsync = ref.watch(areaNameProvider(areaId));
    return areaAsync.maybeWhen(
      data: (name) => Text(
        name,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No saved locations yet',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Save your home, work, or favourite spots so you can quickly tag them in posts.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add your first location'),
            ),
          ],
        ),
      ),
    );
  }
}
