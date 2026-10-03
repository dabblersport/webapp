import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// A flat list row as the design draws it (H06): leading glyph, title,
/// optional subtitle and trailing slot, hairline underneath. No DS class
/// draws an unboxed row (DabblerInputRow is a filled card), so this is a
/// composition of DS tokens and DabblerDivider.
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
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    final titleStyle = (selected ? DabblerType.headline : DabblerType.body)
        .resolveForDirection(direction)
        .copyWith(
          color: brand || selected ? colors.brandPrimary : colors.textPrimary,
        );

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DabblerSpacing.space4,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: DabblerSpacing.space4),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: titleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: DabblerType.footnote
                                .resolveForDirection(direction)
                                .copyWith(color: colors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: DabblerSpacing.space4),
                    trailing!,
                  ],
                ],
              ),
            ),
            const DabblerDivider(),
          ],
        ),
      ),
    );
  }
}
