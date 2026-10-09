import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Composer-only parts of the Create game frame (`Home Feed.dc.html:925-1062`,
/// KAN-472). They compose design-system widgets; none restates a DS internal.

/// How a trailing select pill of the frame reads.
enum GamePillState {
  /// Nothing chosen yet: the neutral pill (card fill, card hairline, the
  /// muted value), e.g. "Select", "Date", "Any level".
  idle,

  /// A value is chosen: the value in ink (`dateFg` / `timeFg` `--ink`,
  /// `:3409-3411`; the venue name, KAN-472 ruling 4).
  chosen,

  /// Not available yet: the sunken fill, the faint outline and the subtle ink,
  /// not tappable (`formatBg` / `formatBorder` / `formatFg`, `:3414-3417`).
  locked,
}

/// A trailing pill of a Create game row: the value and a 14dp arrow
/// (`arrow-circle-right`, or `arrow-circle-down` on Skill level).
class GameSelectPill extends StatelessWidget {
  const GameSelectPill({
    super.key,
    required this.label,
    required this.onTap,
    this.state = GamePillState.idle,
    this.trailingIcon = 'arrow-circle-right',
  });

  final String label;
  final VoidCallback? onTap;
  final GamePillState state;
  final String trailingIcon;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    if (state == GamePillState.idle) {
      return DabblerSelectPill(
        label: label,
        trailingIcon: trailingIcon,
        onTap: onTap,
      );
    }
    final locked = state == GamePillState.locked;
    final ink = locked ? colors.textTertiary : colors.textPrimary;
    final fill = locked ? colors.surfaceSunken : colors.surfaceCard;
    // The DS tone pill draws no hairline; the frame's 1px outline is a
    // recorded deviation (no app-local paint, design_system_gate).
    return DabblerSelectPill(
      label: label,
      trailingIcon: trailingIcon,
      tone: DabblerStatusColor(
        base: ink,
        surface: fill,
        strong: ink,
        solid: ink,
      ),
      onTap: locked ? null : onTap,
    );
  }
}

/// The frame's small section caption: 11/13 `--muted`, `padding-top:6px`. The
/// first one also carries the 12 between the sticky header and the scroller,
/// as Create meet-up's does.
class GameSectionLabel extends StatelessWidget {
  const GameSectionLabel(this.label, {super.key, this.first = false});

  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(
      top: first
          ? DabblerSpacing.space4 + DabblerSpacing.space2
          : DabblerSpacing.space2,
    ),
    child: DabblerText(
      label,
      style: DabblerType.caption2,
      tone: DabblerTextTone.tertiary,
    ),
  );
}

/// A row of the frame's option pills (Duration, Join policy, Visibility): the
/// brand fill when chosen, the card fill and hairline otherwise (`pillOpt`,
/// `:2964-2972`), 13/18, `gap:6px`, wrapping.
class GameOptionPills<T> extends StatelessWidget {
  const GameOptionPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: DabblerSpacing.space2,
    runSpacing: DabblerSpacing.space2,
    children: <Widget>[
      for (final o in options)
        DabblerChip(
          label: o.$2,
          size: DabblerChipSize.small,
          selected: o.$1 == selected,
          onTap: () => onSelect(o.$1),
        ),
    ],
  );
}

/// The price input (KAN-472 ruling 1, retained from `0f1cce48`): the DS text
/// field with the AED unit, a decimal keyboard, the helper and the
/// `game_price_required` error, as before; its 24 radius against the frame's
/// field style (radius-lg) is a recorded deviation.
class GamePriceField extends StatelessWidget {
  const GamePriceField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.showError,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DabblerTextField(
      key: const ValueKey<String>('game-price-field'),
      controller: controller,
      placeholder: l.game_price_hint,
      helperText: l.game_price_sub,
      suffixText: l.game_price_unit,
      errorText: showError ? l.game_price_required : null,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
    );
  }
}
