// Extracted from notifications_screen_v2.dart by KAN-147 (pt.A of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-420: the filter rail is DabblerChip pills; the unread count rides on the
// label because the chip has no count slot.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

class ChipData {
  final String key;
  final String label;

  /// DS icon name rendered through [DabblerIcon].
  final String icon;
  final int? count;
  const ChipData(this.key, this.label, this.icon, {this.count});
}

class ChipsRow extends StatelessWidget {
  final List<ChipData> chips;
  final String activeKey;
  final ValueChanged<String> onChanged;
  const ChipsRow({
    super.key,
    required this.chips,
    required this.activeKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DabblerSizing.touchTargetMin + DabblerSpacing.space3,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space6,
          vertical: DabblerSpacing.space1,
        ),
        itemCount: chips.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: DabblerSpacing.space3),
        itemBuilder: (context, i) {
          final c = chips[i];
          return Center(
            child: NotifChip(
              data: c,
              active: c.key == activeKey,
              onTap: () => onChanged(c.key),
            ),
          );
        },
      ),
    );
  }
}

class NotifChip extends StatelessWidget {
  final ChipData data;
  final bool active;
  final VoidCallback onTap;
  const NotifChip({
    super.key,
    required this.data,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = data.count;
    final label = (count != null && count > 0)
        ? '${data.label} ${DabblerType.toWesternDigits('$count')}'
        : data.label;
    return DabblerChip(
      label: label,
      selected: active,
      onTap: onTap,
      leadingIcon: DabblerIcon(
        data.icon,
        size: DabblerSizing.iconSm,
        color: DabblerChip.iconColorFor(
          DabblerColors.of(context),
          selected: active,
        ),
      ),
    );
  }
}
