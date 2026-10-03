import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Shared chrome for the two composers (post, game), built from the Dabbler
/// design system only: the panel, header, footer button, rows, toggles, chips
/// and fields are all `Dabbler*` components, coloured through
/// [DabblerColors].

TextStyle composerType(
  BuildContext context,
  DabblerTypeStyle step,
  Color color, {
  FontWeight? weight,
}) => step
    .resolveForDirection(Directionality.of(context))
    .copyWith(color: color, fontWeight: weight);

/// The composer panel: a drag handle, a title with a Cancel action, the
/// scrolling [children], an optional error banner and the call-to-action.
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
  });

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
    final colors = DabblerColors.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DabblerRadius.xxl),
            ),
            border: Border.all(color: colors.borderDefault),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: DabblerSpacing.space3),
              Container(
                width: DabblerSheet.handleWidth,
                height: DabblerSheet.handleHeight,
                decoration: BoxDecoration(
                  color: colors.borderStrong,
                  borderRadius: BorderRadius.circular(DabblerRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  DabblerSpacing.space8,
                  DabblerSpacing.space4,
                  DabblerSpacing.space4,
                  DabblerSpacing.space2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DabblerText(title, style: DabblerType.title3),
                    ),
                    DabblerButton(
                      label: 'Cancel',
                      tone: DabblerButtonTone.text,
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
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    DabblerSpacing.space8,
                    DabblerSpacing.space2,
                    DabblerSpacing.space8,
                    0,
                  ),
                  child: DabblerBanner(
                    tone: DabblerBannerTone.error,
                    message: errorMessage,
                  ),
                ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  DabblerSpacing.space8,
                  DabblerSpacing.space4,
                  DabblerSpacing.space8,
                  DabblerSpacing.space4 + (keyboard > 0 ? 0 : safeBottom),
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
          ),
        ),
      ),
    );
  }
}

/// Small caps section heading inside a composer.
class ComposerSectionLabel extends StatelessWidget {
  const ComposerSectionLabel({
    super.key,
    required this.label,
    @Deprecated('The design system text has no tracking; the value is ignored.')
    this.letterSpacing,
  });

  final String label;

  /// Ignored: [DabblerText] carries no letter spacing. Kept so existing
  /// callers compile; remove the argument at the call site.
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    return DabblerText(
      label,
      style: DabblerType.caption1,
      weight: DabblerTextWeight.semibold,
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
    final colors = DabblerColors.of(context);
    final color = onTap == null ? colors.textTertiary : colors.textSecondary;
    final direction = Directionality.of(context);
    final glyph = caret == ComposerSelectCaret.down
        ? 'arrow-down-1'
        : (direction == TextDirection.rtl ? 'arrow-left-2' : 'arrow-right-3');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: DabblerSizing.touchTargetMin,
          maxWidth: 190,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: DabblerText(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DabblerType.footnote,
                tone: onTap == null
                    ? DabblerTextTone.tertiary
                    : DabblerTextTone.secondary,
              ),
            ),
            const SizedBox(width: DabblerSpacing.space1),
            DabblerIcon(glyph, size: DabblerSizing.iconInline, color: color),
          ],
        ),
      ),
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

/// Opens [builder] as a design-system sheet that sizes to its content (capped
/// by the design system's content max fraction). All composer pickers go
/// through here so they share one sheet chrome.
Future<T?> showComposerSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) => showDabblerSheet<T>(
  context: context,
  title: title,
  detent: DabblerSheetDetent.content,
  builder: builder,
);

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
  });

  final String title;
  final String? subtitle;
  final String? icon;
  final bool selected;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return DabblerInputRow(
      title: title,
      subtitle: subtitle,
      leading: icon == null
          ? null
          : DabblerIcon(
              icon!,
              size: DabblerSizing.iconRow,
              color: selected ? colors.brandPrimary : colors.textSecondary,
            ),
      trailing: selected
          ? DabblerIcon(
              'tick-circle',
              weight: DabblerIconWeight.bold,
              size: DabblerSizing.iconRow,
              color: colors.brandPrimary,
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      DabblerSpacing.space6,
      0,
      DabblerSpacing.space6,
      DabblerSpacing.space3,
    ),
    child: DabblerTextField(
      variant: DabblerTextFieldVariant.search,
      controller: controller,
      placeholder: placeholder,
      onChanged: onChanged,
    ),
  );
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
    padding: const EdgeInsetsDirectional.fromSTEB(
      DabblerSpacing.space6,
      0,
      DabblerSpacing.space6,
      DabblerSpacing.space2,
    ),
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: DabblerButton(
        label: 'Clear',
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
