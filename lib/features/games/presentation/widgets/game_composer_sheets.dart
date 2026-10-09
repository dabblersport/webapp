import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Opens one of the Create game sub-sheets (format, date, time, venue, skill)
/// in the Home Feed design's pick-sheet frame (KAN-473,
/// `Home Feed.dc.html:1063-1128`): the page-coloured DS sheet sized to its
/// content and capped at [contentMaxFraction] (`sheetP80`; the place sheet's
/// `sheetP74` passes [DabblerSheet.contentMaxFractionMedium]), the 17/22
/// semibold title with an optional 12/16 caption [subtitle], an optional
/// header Clear and a small neutral Cancel, the `--faint` hairline under the
/// header (the place sheet has none, `:820`: pass [headerDivider] false), and the design's 48dp pill foot (`height:48px`,
/// `border-radius: var(--radius-pill)`, 15/20) — the DS
/// [DabblerComposerSubmit], where [showComposerSheet]'s footer is the 45dp
/// DS button.
///
/// Composer-only: it reuses the kit's title and header actions and changes no
/// kit default. [opener] must sit inside a [ComposerFrameScope] for the kit's
/// framed rows and search box to draw as the frame does.
Future<T?> showGameComposerSheet<T>(
  BuildContext opener, {
  required String title,
  required WidgetBuilder builder,
  String? subtitle,
  VoidCallback? onClear,
  ComposerSheetConfirm? confirm,
  double? contentMaxFraction,
  bool headerDivider = true,
}) => showDabblerSheet<T>(
  context: opener,
  title: title,
  titleWidget: composerSheetTitle(title, subtitle: subtitle),
  detent: DabblerSheetDetent.content,
  contentMaxFraction:
      contentMaxFraction ?? DabblerSheet.defaultContentMaxFraction,
  pageBackground: true,
  showCloseButton: false,
  headerDivider: headerDivider,
  hairlineOutside: true,
  headerActionBuilder: (ctx) =>
      composerSheetHeaderActions(opener, ctx, onClear: onClear),
  footerBuilder: confirm == null
      ? null
      : (_) => GameComposerSheetFoot(confirm: confirm),
  builder: composerFrameBuilder(opener, builder),
);

/// The 48dp pill foot of a Create game sub-sheet, live-enabled through
/// [ComposerSheetConfirm.enabledWhen] when set.
class GameComposerSheetFoot extends StatelessWidget {
  const GameComposerSheetFoot({super.key, required this.confirm});

  final ComposerSheetConfirm confirm;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable:
        confirm.enabledWhen ?? ValueNotifier<bool>(confirm.enabled),
    builder: (_, on, __) => DabblerComposerSubmit(
      label: confirm.label,
      enabled: on,
      onPressed: confirm.onTap,
    ),
  );
}

/// One option row of a Create game sub-sheet, as the design draws it: no
/// inline padding (the sheet's gutter is the row's), [verticalPadding] above
/// and below (14 on the format sheet, `padding:14px 0`, `:1110`; 12 on the
/// place sheet, `padding:12px 0`, `:846`), an optional glyph (21, the DS row icon; the design's 20) 12 before
/// the text, the title 15/20 (brand ink when [selected]) over a muted
/// [subtitle] 1 under it, the bold brand tick-circle at the end when
/// [selected], and the `--faint` hairline under the row.
///
/// Composer-only; the shared [ComposerPickerRow] keeps the DS input row's
/// 14/16 padding for every other caller.
class GameSheetOptionRow extends StatelessWidget {
  const GameSheetOptionRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.subtitleStyle = DabblerType.footnote,
    this.icon,
    this.selected = false,
    this.verticalPadding,
  });

  /// The format sheet's row padding (`padding:14px 0`): the DS input row's
  /// 14, which is not a step of the spacing grid.
  static final double formatPadding = DabblerInputRow.defaultPadding.top;

  /// The place sheet's row padding (`padding:12px 0`).
  static const double placePadding = DabblerSpacing.space4;

  final String title;
  final String? subtitle;

  /// 13/18 on the format sheet (`:1112`), 12/16 on the place sheet (`:852`).
  final DabblerTypeStyle subtitleStyle;
  final String? icon;
  final bool selected;

  /// Defaults to [formatPadding].
  final double? verticalPadding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: verticalPadding ?? formatPadding,
              ),
              child: Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    DabblerIcon(
                      icon!,
                      weight: selected
                          ? DabblerIconWeight.bold
                          : DabblerIconWeight.linear,
                      size: DabblerSizing.iconRow,
                      color: selected
                          ? colors.brandPrimary
                          : colors.textSecondary,
                    ),
                    const SizedBox(width: DabblerSpacing.space4),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        DabblerText(
                          title,
                          style: DabblerType.subheadline,
                          tone: selected
                              ? DabblerTextTone.brand
                              : DabblerTextTone.primary,
                          maxLines: 1,
                        ),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: DabblerSizing.borderDefault),
                          DabblerText(
                            subtitle!,
                            style: subtitleStyle,
                            tone: DabblerTextTone.secondary,
                            maxLines: 1,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selected) ...<Widget>[
                    const SizedBox(width: DabblerSpacing.space4),
                    DabblerIcon(
                      'tick-circle',
                      weight: DabblerIconWeight.bold,
                      size: DabblerSizing.iconRow,
                      color: colors.brandPrimary,
                    ),
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
