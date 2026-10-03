import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// A flat list row as the design draws it (H06): leading glyph, title,
/// optional subtitle and trailing slot, hairline underneath — the design
/// system's flat [DabblerInputRow] (`flat: true`).
///
/// [selected] only restyles the title and marks the node selected; the
/// caller's own radio stays the visible control, so the row's built-in tick
/// (`DabblerInputRow.selected`) is not used.
class PickerRow extends StatelessWidget {
  const PickerRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.brand = false,
  });

  final String title;
  final Widget? leading;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;

  /// Draws the title in the brand colour ("Use current location").
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final bool accent = brand || selected;
    final row = DabblerInputRow(
      flat: true,
      leading: leading,
      title: accent ? null : title,
      titleSpan: accent
          ? TextSpan(
              text: title,
              style: DabblerText.resolveStyle(
                context,
                style: DabblerType.subheadline,
                weight: selected ? DabblerTextWeight.semibold : null,
                tone: DabblerTextTone.brand,
              ),
            )
          : null,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
    return selected ? Semantics(selected: true, child: row) : row;
  }
}
