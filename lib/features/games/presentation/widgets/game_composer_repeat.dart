import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The Repeat block of the Create game frame (KAN-697, `Recurring LTR.dc.html`
/// and `Recurring RTL.dc.html`): a sunken row (36 icon circle, the label over
/// the current value, an end chevron) that opens a sunken panel holding the
/// three equal option pills, the Ends card and the series hint. It composes
/// design-system roles only; the copy comes from the KAN-696 keys.
class GameRepeatSection<T> extends StatelessWidget {
  const GameRepeatSection({
    super.key,
    required this.label,
    required this.valueText,
    required this.open,
    required this.onToggle,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.endLabel,
    required this.endValue,
    required this.onPickEnd,
    required this.hint,
    this.showEnds = true,
    this.locked = false,
    this.lockedTitle = '',
    this.lockedMessage = '',
    this.limitReached = false,
    this.limitTitle = '',
    this.limitMessage = '',
    this.limitAction = '',
  });

  /// "Repeat".
  final String label;

  /// The current value line ("Does not repeat", "Repeats every week on …").
  final String valueText;
  final bool open;
  final VoidCallback onToggle;

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelect;

  /// The Ends card: the label and its value line.
  final String endLabel;
  final String endValue;
  final VoidCallback onPickEnd;

  /// The one-line series hint under the card.
  final String hint;

  /// Whether the Ends card shows (only while Repeat is on).
  final bool showEnds;

  /// A paid game: the row can't open and two lines say why.
  final bool locked;
  final String lockedTitle;
  final String lockedMessage;

  /// The series is at its cap: the warning card with [limitAction].
  final bool limitReached;
  final String limitTitle;
  final String limitMessage;
  final String limitAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: DabblerSpacing.space3,
      children: <Widget>[
        DabblerSurface.sunken(
          radius: DabblerRadius.lg,
          child: DabblerListRow(
            key: const ValueKey<String>('game-repeat-row'),
            leading: const DabblerIconTile.named('repeat'),
            overline: label,
            title: valueText,
            trailing: locked
                ? null
                : DabblerIcon(open ? 'arrow-circle-up' : 'arrow-circle-down'),
            onTap: locked ? null : onToggle,
          ),
        ),
        if (locked)
          DabblerBanner(
            tone: DabblerBannerTone.info,
            title: lockedTitle,
            message: lockedMessage,
          )
        else if (open) ...<Widget>[
          DabblerSurface.sunken(
            key: const ValueKey<String>('game-repeat-panel'),
            radius: DabblerRadius.lg,
            padding: const EdgeInsets.all(DabblerSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: DabblerSpacing.space4,
              children: <Widget>[
                Row(
                  spacing: DabblerSpacing.space2,
                  children: <Widget>[
                    for (final o in options)
                      Expanded(
                        child: DabblerButton(
                          label: o.$2,
                          size: DabblerButtonSize.block,
                          tone: o.$1 == selected
                              ? DabblerButtonTone.primary
                              : DabblerButtonTone.outlined,
                          onPressed: () => onSelect(o.$1),
                        ),
                      ),
                  ],
                ),
                if (showEnds)
                  DabblerSurface.card(
                    radius: DabblerRadius.md,
                    child: DabblerListRow(
                      key: const ValueKey<String>('game-repeat-end'),
                      leading: const DabblerIcon('calendar'),
                      overline: endLabel,
                      title: endValue,
                      onTap: onPickEnd,
                    ),
                  ),
                DabblerText(
                  hint,
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.tertiary,
                ),
              ],
            ),
          ),
          if (limitReached)
            DabblerBanner(
              key: const ValueKey<String>('game-repeat-limit'),
              tone: DabblerBannerTone.warning,
              title: limitTitle,
              message: limitMessage,
              action: DabblerBannerAction(
                label: limitAction,
                onPressed: onPickEnd,
              ),
            ),
        ],
      ],
    );
  }
}
