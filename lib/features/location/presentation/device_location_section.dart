import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/features/location/presentation/active_location_label.dart';
import 'package:dabbler/features/location/presentation/set_location_when_denied.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// "Location on this device" on Settings > Location (KAN-589): an Auto / Manual
/// choice, per device and kept across restarts by the KAN-586 device store.
///
/// Auto follows the GPS fix; the OS permission is asked once (never again), and
/// a denial opens the manual "Set location" drawer while the mode stays Manual.
/// Manual shows the chosen place with a Change action that opens the picker.
/// No street address and nothing written to the public Profile city/country.
class DeviceLocationSection extends ConsumerWidget {
  const DeviceLocationSection({super.key});

  static const _autoId = 'auto';
  static const _manualId = 'manual';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ActiveLocationState? state = ref
        .watch(activeLocationProvider)
        .valueOrNull;
    final bool auto = isAutoMode(state);
    final bool denied = state is ActiveLocationDenied;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DabblerText(l10n.location_device_section, style: DabblerType.headline),
        const DabblerGap.v(DabblerSpacing.space3),
        DabblerTabs(
          variant: DabblerTabsVariant.segmented,
          label: l10n.location_device_section,
          value: auto ? _autoId : _manualId,
          items: [
            DabblerTabItem(id: _autoId, label: l10n.location_mode_auto),
            DabblerTabItem(id: _manualId, label: l10n.location_mode_manual),
          ],
          onChanged: (id) => id == _autoId
              ? _chooseAuto(context, ref)
              : _chooseManual(context, ref),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        if (auto)
          DabblerText(
            l10n.location_mode_auto_hint,
            style: DabblerType.footnote,
            tone: DabblerTextTone.secondary,
          )
        else
          Row(
            children: [
              Expanded(
                child: DabblerText(
                  state is ActiveLocationReady ||
                          state is ActiveLocationCityOnly
                      ? activeLocationLabel(l10n, state)
                      : l10n.location_mode_none_chosen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DabblerType.body,
                ),
              ),
              DabblerButton(
                label: l10n.location_mode_change,
                tone: DabblerButtonTone.text,
                onPressed: () => HomeLocationPickerSheet.show(context),
              ),
            ],
          ),
        if (denied) ...[
          const DabblerGap.v(DabblerSpacing.space2),
          DabblerText(
            l10n.location_intro_denied,
            style: DabblerType.footnote,
            tone: DabblerTextTone.secondary,
          ),
        ],
      ],
    );
  }

  Future<void> _chooseAuto(BuildContext context, WidgetRef ref) async {
    if (isAutoMode(ref.read(activeLocationProvider).valueOrNull)) return;
    final AutoSwitchResult r = await ref
        .read(activeLocationProvider.notifier)
        .switchToAuto();
    if (!context.mounted || r == AutoSwitchResult.applied) return;
    if (r == AutoSwitchResult.denied) await showSetLocationDrawer(context);
  }

  /// Manual keeps the place the device shows now (written as this device's
  /// Manual choice); with no place yet, the "Set location" drawer opens.
  Future<void> _chooseManual(BuildContext context, WidgetRef ref) async {
    final ActiveLocationState? s = ref.read(activeLocationProvider).valueOrNull;
    if (s is ActiveLocationReady && isAutoMode(s)) {
      final ActiveLocation l = s.location;
      await ref
          .read(activeLocationProvider.notifier)
          .useManualPoint(
            l.lat,
            l.lng,
            l.area.name,
            city: l.area.city,
            area: l.area.name,
          );
      return;
    }
    if (s is ActiveLocationReady) return;
    await showSetLocationDrawer(context);
  }
}
