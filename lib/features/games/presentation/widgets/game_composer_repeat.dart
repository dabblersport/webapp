import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';

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
    final colors = DabblerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: DabblerSpacing.space3,
      children: <Widget>[
        _RepeatRow(
          label: label,
          valueText: valueText,
          open: open && !locked,
          onTap: locked ? null : onToggle,
        ),
        if (locked)
          DabblerBanner(
            tone: DabblerBannerTone.info,
            title: lockedTitle,
            message: lockedMessage,
          )
        else if (open) ...<Widget>[
          DecoratedBox(
            key: const ValueKey<String>('game-repeat-panel'),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: DabblerRadius.lgAll,
            ),
            child: Padding(
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
                          child: _RepeatPill(
                            label: o.$2,
                            selected: o.$1 == selected,
                            onTap: () => onSelect(o.$1),
                          ),
                        ),
                    ],
                  ),
                  if (showEnds)
                    _EndsCard(
                      label: endLabel,
                      value: endValue,
                      onTap: onPickEnd,
                    ),
                  _Caption(hint),
                ],
              ),
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

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    return Text(
      text,
      style: DabblerType.footnote
          .resolveForDirection(dir)
          .copyWith(color: DabblerColors.of(context).textTertiary),
    );
  }
}

/// The frame's sunken row: 36 icon circle, label over value, end chevron.
class _RepeatRow extends StatelessWidget {
  const _RepeatRow({
    required this.label,
    required this.valueText,
    required this.open,
    required this.onTap,
  });

  final String label;
  final String valueText;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final dir = Directionality.of(context);
    return Semantics(
      button: onTap != null,
      expanded: onTap == null ? null : open,
      child: Material(
        color: colors.surfaceSunken,
        borderRadius: DabblerRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey<String>('game-repeat-row'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DabblerSpacing.space5,
                vertical: DabblerSpacing.space4,
              ),
              child: Row(
                spacing: DabblerSpacing.space4,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: DabblerIcon(
                          'repeat',
                          size: 18,
                          color: colors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          label,
                          style: DabblerType.footnote
                              .resolveForDirection(dir)
                              .copyWith(color: colors.textTertiary),
                        ),
                        Text(
                          valueText,
                          style: DabblerType.subheadline
                              .resolveForDirection(dir)
                              .copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Transform.rotate(
                    angle: open ? 3.14159265358979 : 0,
                    child: DabblerIcon(
                      'arrow-circle-down',
                      size: 18,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the three equal 44dp option pills.
class _RepeatPill extends StatelessWidget {
  const _RepeatPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final dir = Directionality.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.brandPrimary : colors.surfaceCard,
        borderRadius: DabblerRadius.pillAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DabblerSpacing.space2,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: DabblerType.footnote
                      .resolveForDirection(dir)
                      .copyWith(
                        color: selected ? colors.onBrand : colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Ends card inside the panel: calendar glyph, label over value.
class _EndsCard extends StatelessWidget {
  const _EndsCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final dir = Directionality.of(context);
    return Semantics(
      button: true,
      child: Material(
        color: colors.surfaceCard,
        borderRadius: DabblerRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey<String>('game-repeat-end'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              child: Row(
                spacing: DabblerSpacing.space4,
                children: <Widget>[
                  DabblerIcon(
                    'calendar',
                    weight: DabblerIconWeight.bold,
                    size: 18,
                    color: colors.brandPrimary,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          label,
                          style: DabblerType.footnote
                              .resolveForDirection(dir)
                              .copyWith(color: colors.textTertiary),
                        ),
                        Text(
                          value,
                          style: DabblerType.subheadline
                              .resolveForDirection(dir)
                              .copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
