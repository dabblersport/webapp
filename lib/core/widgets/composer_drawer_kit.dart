import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import 'package:dabbler/l10n/app_localizations.dart';

/// Shared chrome for the two composers (post, game), built from the Dabbler
/// design system only: the panel, header, footer button, rows, toggles, chips
/// and fields are all `Dabbler*` components, coloured through
/// [DabblerColors].

/// Marks a subtree as drawn in the Create Post design frame
/// (`Home Feed.dc.html` "Create post", `:470-1000`).
///
/// **Opt-in, default off.** It exists only below a
/// `ComposerDrawerShell(designFrame: true)` and in the sheets that a context
/// below such a shell opens through [showComposerSheet] /
/// [composerFrameBuilder]. Every kit widget that draws differently in the frame
/// asks [active] and takes its existing code path when the answer is false, so
/// the game and meet-up composers, and every other caller, render exactly as
/// before (KAN-460, `tmp/kan460/blast_radius.md`).
class ComposerFrameScope extends InheritedWidget {
  const ComposerFrameScope({super.key, required super.child});

  /// Whether [context] sits inside the Create Post design frame.
  static bool active(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ComposerFrameScope>() != null;

  @override
  bool updateShouldNotify(ComposerFrameScope oldWidget) => false;
}

/// Wraps [builder] so the sheet it builds keeps the Create Post design frame
/// when [opener] is inside it (a sheet is pushed on the root navigator, outside
/// the opener's tree). Returns [builder] itself otherwise.
WidgetBuilder composerFrameBuilder(BuildContext opener, WidgetBuilder builder) =>
    ComposerFrameScope.active(opener)
    ? (ctx) => ComposerFrameScope(child: builder(ctx))
    : builder;

/// The composer sheet content: a title with a Cancel action, the
/// scrolling [children], an optional error banner and the call-to-action.
///
/// With [designFrame] it is drawn as the Create Post frame: a page-coloured
/// panel, the drag handle, 18dp gutters, and the call-to-action inside the
/// scroll area under a hairline instead of pinned below it.
class ComposerDrawerShell extends StatelessWidget {
  const ComposerDrawerShell({
    super.key,
    required this.title,
    required this.ctaLabel,
    required this.onCtaTap,
    required this.children,
    this.canSubmit = true,
    this.isSubmitting = false,
    this.errorMessage,
    this.bottomSpacer = DabblerSpacing.space4,
    this.designFrame = false,
  });

  /// Draws the Create Post design frame (default false: the shell every other
  /// composer uses).
  final bool designFrame;

  final String title;
  final String ctaLabel;
  final VoidCallback onCtaTap;
  final bool canSubmit;
  final bool isSubmitting;
  final List<Widget> children;
  final String? errorMessage;
  final double bottomSpacer;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    if (designFrame) return _buildFrame(context, keyboardOpen, safeBottom);

    // The route's modal frame supplies the sheet surface, its corners, the
    // keyboard inset and the height cap; the shell is only its content.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            DabblerSpacing.space8,
            DabblerSpacing.space6,
            DabblerSpacing.space4,
            DabblerSpacing.space2,
          ),
          child: Row(
            children: [
              Expanded(child: DabblerText(title, style: DabblerType.title3)),
              DabblerButton(
                label: AppLocalizations.of(context).composer_cancel,
                tone: DabblerButtonTone.neutral,
                size: DabblerButtonSize.small,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...children,
                SizedBox(height: bottomSpacer),
              ],
            ),
          ),
        ),
        if (errorMessage != null && errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: DabblerSpacing.space8,
              top: DabblerSpacing.space2,
              end: DabblerSpacing.space8,
            ),
            child: DabblerBanner(
              tone: DabblerBannerTone.error,
              message: errorMessage,
            ),
          ),
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: DabblerSpacing.space8,
            top: DabblerSpacing.space4,
            end: DabblerSpacing.space8,
            bottom: keyboardOpen
                ? DabblerSpacing.space4
                : DabblerSpacing.space4 + safeBottom,
          ),
          child: DabblerButton(
            label: ctaLabel,
            fullWidth: true,
            loading: isSubmitting,
            disabled: !canSubmit,
            onPressed: canSubmit && !isSubmitting ? onCtaTap : null,
          ),
        ),
      ],
    );
  }
}

/// `AdaptiveModalPage`'s compact breakpoint (`_kCompactWidth`): below it the
/// route is a bottom sheet, from it a centred dialog.
const double _kAdaptiveCompactWidth = 600;

extension on ComposerDrawerShell {
  /// The Create Post frame (`Home Feed.dc.html:470-574`): handle, title row,
  /// then one scroll area that ends with the Post button under a hairline.
  Widget _buildFrame(BuildContext context, bool keyboardOpen, double safeBottom) {
    final colors = DabblerColors.of(context);
    // The frame's sheet is its `max-height: 94%` cap whenever the content
    // fills it (the scroll area is `flex: 1`, `Home Feed.dc.html:481`; measured
    // 800.9 of 852 even with an empty draft), so on a phone the column takes
    // the height the route offers instead of shrink-wrapping. On a wide screen
    // the route is a centred dialog and stays content-sized.
    final fill = MediaQuery.sizeOf(context).width < _kAdaptiveCompactWidth;
    return ComposerFrameScope(
      // The route's frame paints the card colour; the design's sheet is the
      // page colour (`sheetP94`: `background: var(--surface-page)`). The sheet
      // is as tall as this column, so painting here covers the whole panel.
      child: Container(
        key: const ValueKey<String>('composer-frame-surface'),
        decoration: BoxDecoration(
          color: colors.bgPrimary,
          // The sheet's own 1px `--outline-card` edge on top and sides, with
          // the content laid out inside it (`hairlineOutside`).
          border: Border(
            top: BorderSide(
              color: colors.borderDefault,
              width: DabblerSizing.borderDefault,
            ),
            left: BorderSide(
              color: colors.borderDefault,
              width: DabblerSizing.borderDefault,
            ),
            right: BorderSide(
              color: colors.borderDefault,
              width: DabblerSizing.borderDefault,
            ),
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DabblerRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ComposerHandle(),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: DabblerSpacing.space6,
                end: DabblerSpacing.space6,
                bottom: DabblerSpacing.space2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DabblerText(title, style: DabblerType.title3),
                  ),
                  DabblerButton(
                    label: AppLocalizations.of(context).composer_cancel,
                    tone: DabblerButtonTone.neutral,
                    size: DabblerButtonSize.small,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Flexible(
              fit: fill ? FlexFit.tight : FlexFit.loose,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...children,
                    if (errorMessage != null && errorMessage!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: DabblerSpacing.space6,
                          end: DabblerSpacing.space6,
                          top: DabblerSpacing.space5,
                        ),
                        child: DabblerBanner(
                          tone: DabblerBannerTone.error,
                          message: errorMessage,
                        ),
                      ),
                    // The Post block scrolls with the content: 15dp under the
                    // options, a `--faint` hairline, padding 12 / 24, a 48dp
                    // pill (`:565-568`).
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: DabblerSpacing.space6,
                        end: DabblerSpacing.space6,
                        top: DabblerSpacing.space5,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: colors.bgTertiary,
                              width: DabblerSizing.borderDefault,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            top: DabblerSpacing.space4,
                            bottom: keyboardOpen
                                ? DabblerSpacing.space8
                                : DabblerSpacing.space8 + safeBottom,
                          ),
                          // 48dp tall (`height: 48px`), against the DS
                          // button's 45dp floor.
                          child: SizedBox(
                            height: DabblerSpacing.space11,
                            child: DabblerButton(
                              label: ctaLabel,
                              fullWidth: true,
                              loading: isSubmitting,
                              disabled: !canSubmit,
                              onPressed: canSubmit && !isSubmitting
                                  ? onCtaTap
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // The scroll area's own `padding-block: 0 18px`, then the
                    // sheet body's 18dp bottom padding.
                    const SizedBox(height: DabblerSpacing.space6),
                    const SizedBox(height: DabblerSpacing.space6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sheet's 40x4 grab bar in its 45dp row (`Sheet.jsx:101-104`), as the
/// Create post frame draws it above the title.
class _ComposerHandle extends StatelessWidget {
  const _ComposerHandle();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: DabblerSizing.touchTargetMin,
      child: Center(
        child: Container(
          width: DabblerSheet.handleWidth,
          height: DabblerSheet.handleHeight,
          decoration: BoxDecoration(
            color: DabblerColors.of(context).borderStrong,
            borderRadius: DabblerRadius.pillAll,
          ),
        ),
      ),
    ),
  );
}

/// Small section heading inside a composer.
class ComposerSectionLabel extends StatelessWidget {
  const ComposerSectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DabblerText(
      label,
      style: DabblerType.caption1,
      tone: DabblerTextTone.secondary,
    );
  }
}

/// One settings row: a DS icon, title, optional subtitle and a trailing
/// control. [icon] is a DS icon name.
class ComposerSettingsRow extends StatelessWidget {
  const ComposerSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    if (ComposerFrameScope.active(context)) {
      // The frame's option row (`:529-558`): `padding: 12px 0`, a 20dp glyph,
      // 15/20 title over a 13/18 note and a `border-bottom: 1px solid
      // var(--faint)` that takes its own pixel: 63 + 1 = 64dp. The DS `flat` +
      // `dense` row supplies the rest; its own hairline is painted inside the
      // padding (no layout), so the pixel is added here with the same token.
      return Container(
        decoration: showDivider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.bgTertiary,
                    width: DabblerSizing.borderDefault,
                  ),
                ),
              )
            : null,
        child: DabblerInputRow(
          title: title,
          subtitle: subtitle,
          leading: DabblerIcon(
            icon,
            size: DabblerHomeFrame.listRowGlyph,
            color: colors.textSecondary,
          ),
          trailing: trailing,
          onTap: onTap,
          flat: true,
          dense: true,
          showDivider: false,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DabblerInputRow(
          title: title,
          subtitle: subtitle,
          leading: DabblerIcon(
            icon,
            size: DabblerSizing.iconRow,
            color: colors.textSecondary,
          ),
          trailing: trailing,
          onTap: onTap,
        ),
        if (showDivider) const DabblerDivider(),
      ],
    );
  }
}

/// The on/off switch.
class ComposerToggle extends StatelessWidget {
  const ComposerToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => DabblerToggle(
    checked: value,
    onChanged: onChanged,
    semanticLabel: semanticLabel,
    // The frame's switch is its painted 48x28 (`hint-size="48px,28px"`), with
    // the 45dp target kept as a hit area only; elsewhere the 45dp box stays.
    compactHitArea: ComposerFrameScope.active(context),
  );
}

enum ComposerSelectCaret { down, right }

/// A value shown at the end of a settings row, with a caret. A null [onTap]
/// renders it disabled.
class ComposerSelectPill extends StatelessWidget {
  const ComposerSelectPill({
    super.key,
    required this.value,
    this.caret = ComposerSelectCaret.right,
    this.onTap,
  });

  final String value;
  final ComposerSelectCaret caret;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return DabblerSelectPill(
      label: value,
      onTap: onTap,
      trailingIcon: caret == ComposerSelectCaret.down
          ? 'arrow-circle-down'
          : (rtl ? 'arrow-circle-left' : 'arrow-circle-right'),
    );
  }
}

/// A short value chip for the date/time/duration/player-count rows.
class ComposerCompactSelectPill extends StatelessWidget {
  const ComposerCompactSelectPill({
    super.key,
    required this.value,
    this.suffixLabel,
    this.highlighted = false,
    this.onTap,
  });

  final String value;
  final String? suffixLabel;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DabblerChip(
    label: suffixLabel == null ? value : '$value $suffixLabel',
    selected: highlighted,
    onTap: onTap,
  );
}

/// A selectable option chip (join policy, visibility).
class ComposerPolicyChip extends StatelessWidget {
  const ComposerPolicyChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      DabblerChip(label: label, selected: selected, onTap: onTap);
}

/// A text input. [minLines] above 1 gives the multiline variant.
class ComposerGlassInput extends StatelessWidget {
  const ComposerGlassInput({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.minLines = 1,
    this.maxLines,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final int? maxLines;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => DabblerTextField(
    variant: minLines > 1
        ? DabblerTextFieldVariant.multiline
        : DabblerTextFieldVariant.standard,
    controller: controller,
    focusNode: focusNode,
    placeholder: hint,
    rows: minLines > 1 ? minLines : 3,
    onChanged: onChanged,
  );
}

/// The footer action of a composer sheet (`Confirm`).
class ComposerSheetConfirm {
  const ComposerSheetConfirm({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.enabledWhen,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  /// A live enabled state (the Continue button of the date step); wins over
  /// [enabled] when set.
  final ValueListenable<bool>? enabledWhen;
}

/// Opens [builder] as a design-system sheet that sizes to its content, capped
/// at the design system's default content cap (`Home Feed.dc.html`
/// `sheetP80`: `max-height: 80%`, `height: auto`). All composer pickers share
/// one sheet chrome: the page-coloured panel, a title with an optional
/// [subtitle], an optional text [onClear] and a neutral Cancel at the header's
/// end, and an optional [confirm] footer (`Home Feed.dc.html:578-690`).
///
/// A picker the frame caps elsewhere (vibes at 82%, places at 74%) opens
/// `showDabblerSheet` itself with the same chrome — [composerSheetTitle],
/// [composerSheetHeaderActions] and [composerSheetFooter] — and its own
/// `contentMaxFraction`.
Future<T?> showComposerSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  String? subtitle,
  VoidCallback? onClear,
  ComposerSheetConfirm? confirm,
}) => showDabblerSheet<T>(
  context: context,
  title: title,
  titleWidget: composerSheetTitle(title, subtitle: subtitle),
  detent: DabblerSheetDetent.content,
  pageBackground: true,
  showCloseButton: false,
  // The Create post frame's pick sheets draw a `--faint` hairline under the
  // header (`:577`, `:614`, `:731`, `:879`); only inside that frame.
  headerDivider: ComposerFrameScope.active(context),
  hairlineOutside: ComposerFrameScope.active(context),
  headerActionBuilder: (ctx) =>
      composerSheetHeaderActions(context, ctx, onClear: onClear),
  footerBuilder: confirm == null ? null : (ctx) => composerSheetFooter(confirm),
  builder: composerFrameBuilder(context, builder),
);

/// The title block of a composer sheet: the title in headline semibold and an
/// optional caption [subtitle] under it.
Widget composerSheetTitle(String title, {String? subtitle}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
    DabblerText(
      title,
      style: DabblerType.headline,
      weight: DabblerTextWeight.semibold,
    ),
    if (subtitle != null)
      DabblerText(
        subtitle,
        style: DabblerType.caption1,
        tone: DabblerTextTone.secondary,
      ),
  ],
);

/// The header end of a composer sheet: an optional text Clear (runs [onClear]
/// and closes) and a neutral Cancel. [opener] is the context the sheet was
/// opened from (its language), [sheet] the sheet's own.
Widget composerSheetHeaderActions(
  BuildContext opener,
  BuildContext sheet, {
  VoidCallback? onClear,
}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    if (onClear != null && ComposerFrameScope.active(opener)) ...[
      // The frame's Clear is a plain 13/18 muted word, not a text button
      // (`:670`): the secondary text role (D-003: `--muted` is not a text
      // colour), 12dp from Cancel (`gap: 12px`).
      _ComposerClearLink(
        label: AppLocalizations.of(sheet).composer_clear,
        onTap: () {
          onClear();
          Navigator.of(sheet).maybePop();
        },
      ),
      const SizedBox(width: DabblerSpacing.space4),
    ] else if (onClear != null)
      DabblerButton(
        label: AppLocalizations.of(sheet).composer_clear,
        tone: DabblerButtonTone.text,
        size: DabblerButtonSize.small,
        onPressed: () {
          onClear();
          Navigator.of(sheet).maybePop();
        },
      ),
    DabblerButton(
      label: AppLocalizations.of(opener).composer_cancel,
      tone: DabblerButtonTone.neutral,
      size: DabblerButtonSize.small,
      onPressed: () => Navigator.of(sheet).maybePop(),
    ),
  ],
);

class _ComposerClearLink extends StatelessWidget {
  const _ComposerClearLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: DabblerSizing.touchTargetMin,
          minHeight: DabblerSizing.touchTargetMin,
        ),
        child: Center(
          child: DabblerText(
            label,
            style: DabblerType.footnote,
            tone: DabblerTextTone.secondary,
          ),
        ),
      ),
    ),
  );
}

/// The pinned footer of a composer sheet: the full-width [confirm] button,
/// live-enabled through [ComposerSheetConfirm.enabledWhen] when set.
Widget composerSheetFooter(ComposerSheetConfirm confirm) =>
    ValueListenableBuilder<bool>(
      valueListenable:
          confirm.enabledWhen ?? ValueNotifier<bool>(confirm.enabled),
      builder: (_, on, __) => DabblerButton(
        label: confirm.label,
        fullWidth: true,
        disabled: !on,
        onPressed: on ? confirm.onTap : null,
      ),
    );

/// One option of a [showComposerChoiceSheet].
class ComposerChoice<T> {
  const ComposerChoice({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String title;
  final String? subtitle;
  final String? icon;
}

/// A pick-one composer sheet: rows with a check on the chosen one and a
/// `Confirm` footer that applies the choice (`Home Feed.dc.html:614-648`).
Future<void> showComposerChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<ComposerChoice<T>> choices,
  required T selected,
  required ValueChanged<T> onConfirm,
}) {
  final picked = ValueNotifier<T>(selected);
  return showComposerSheet<void>(
    context,
    title: title,
    confirm: ComposerSheetConfirm(
      label: AppLocalizations.of(context).composer_confirm,
      onTap: () {
        onConfirm(picked.value);
        Navigator.of(context).maybePop();
      },
    ),
    builder: (ctx) => ValueListenableBuilder<T>(
      valueListenable: picked,
      builder: (_, value, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in choices)
            ComposerPickerRow(
              icon: c.icon,
              title: c.title,
              subtitle: c.subtitle,
              selected: value == c.value,
              onTap: () => picked.value = c.value,
            ),
        ],
      ),
    ),
  );
}

/// A tappable list row for the pickers: icon, title, optional subtitle, and a
/// check when [selected].
class ComposerPickerRow extends StatelessWidget {
  const ComposerPickerRow({
    super.key,
    required this.title,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.selected = false,
    this.trailingText,
    this.accent = false,
    this.chevron = false,
    this.divider = true,
  });

  /// Draws the hairline under the row (every picker list of the frames).
  final bool divider;

  /// Draws the glyph in the brand ink (the Add media rows).
  final bool accent;

  /// Draws a trailing `arrow-circle-right` (mirrored in RTL).
  final bool chevron;

  final String title;
  final String? subtitle;
  final String? icon;
  final bool selected;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    // In the Create post frame the chosen row is drawn as the design draws it
    // (`iconType: sel ? 'bold' : 'linear'`, brand title - `:3198-3222`): a
    // filled glyph and a brand-ink title.
    final framedSelected = selected && ComposerFrameScope.active(context);
    final row = DabblerInputRow(
      title: framedSelected ? null : title,
      titleSpan: framedSelected
          ? TextSpan(
              text: title,
              style: DabblerType.subheadline
                  .resolveForDirection(Directionality.of(context))
                  .copyWith(color: colors.brandPrimary),
            )
          : null,
      subtitle: subtitle,
      leading: icon == null
          ? null
          : DabblerIcon(
              icon!,
              weight: framedSelected
                  ? DabblerIconWeight.bold
                  : DabblerIconWeight.linear,
              size: DabblerSizing.iconRow,
              color: selected || accent
                  ? colors.brandPrimary
                  : colors.textSecondary,
            ),
      trailing: selected
          ? DabblerIcon(
              'tick-circle',
              weight: DabblerIconWeight.bold,
              size: DabblerSizing.iconRow,
              color: colors.brandPrimary,
            )
          : chevron
          ? DabblerIcon(
              Directionality.of(context) == TextDirection.rtl
                  ? 'arrow-circle-left'
                  : 'arrow-circle-right',
              size: DabblerSizing.iconSm,
              color: colors.textTertiary,
            )
          : (trailingText == null
                ? null
                : DabblerText(
                    trailingText!,
                    style: DabblerType.caption1,
                    tone: DabblerTextTone.secondary,
                  )),
      onTap: onTap,
    );
    if (!divider) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [row, const DabblerDivider()],
    );
  }
}

/// Search box used by the pickers.
class ComposerSearchField extends StatelessWidget {
  const ComposerSearchField({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (ComposerFrameScope.active(context)) {
      // The frame's search box (`:660-668`): 42dp, `--radius-xxl`, a 16dp
      // glyph, flush with the sheet's 18dp gutter (the sheet already pads its
      // body), 12dp above the list.
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space4),
        child: DabblerTextField(
          variant: DabblerTextFieldVariant.search,
          metrics: DabblerFeedMetrics.drawn,
          controller: controller,
          placeholder: placeholder,
          onChanged: onChanged,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space6,
        end: DabblerSpacing.space6,
        bottom: DabblerSpacing.space3,
      ),
      child: DabblerTextField(
        variant: DabblerTextFieldVariant.search,
        controller: controller,
        placeholder: placeholder,
        onChanged: onChanged,
      ),
    );
  }
}

/// Centred spinner or message for a picker body.
class ComposerCenteredState extends StatelessWidget {
  const ComposerCenteredState.loading({super.key})
    : message = null,
      icon = null;

  const ComposerCenteredState.message(this.message, {super.key, this.icon});

  final String? message;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    if (message == null) {
      return const Center(child: DabblerSpinner());
    }
    return Center(
      child: DabblerEmptyState(icon: icon, text: message),
    );
  }
}

/// A "Clear" action aligned to the end, shown above a picker body.
class ComposerClearRow extends StatelessWidget {
  const ComposerClearRow({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(
      start: DabblerSpacing.space6,
      end: DabblerSpacing.space6,
      bottom: DabblerSpacing.space2,
    ),
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: DabblerButton(
        label: AppLocalizations.of(context).composer_clear,
        tone: DabblerButtonTone.text,
        size: DabblerButtonSize.small,
        onPressed: onClear,
      ),
    ),
  );
}

/// A bounded, scrolling area for a picker's results. The design-system sheet
/// scrolls its own content, so a long list needs a fixed height of its own to
/// scroll (and to report scroll position, as the GIF grid's paging does).
class ComposerScrollArea extends StatelessWidget {
  const ComposerScrollArea({
    super.key,
    required this.child,
    this.fraction = 0.5,
  });

  final Widget child;
  final double fraction;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * fraction,
    child: child,
  );
}
