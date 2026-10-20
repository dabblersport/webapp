import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The app's one bottom-drawer presenter (KAN-596).
///
/// **Why it exists.** The pinned design system's [DabblerSheetRoute]
/// (`dabbler_design_system` `lib/src/overlays/sheet_route.dart:149-165`) wraps
/// the whole page in a `SlideTransition`, and that page is a [DabblerSheet]
/// whose [DabblerScrim] wash is drawn *inside* it
/// (`sheet_panel.dart:143`). So the dimming backdrop slid up with the panel
/// on open and down with it on dismiss. The package is read-only here; this
/// route is the single app-level adapter until the DS fixes its route.
///
/// **What it does instead.** The route has no slide of its own. It drives
/// [DabblerSheet.open] from its animation status, which the DS sheet already
/// animates correctly: the wash fades in place ([DabblerScrim]'s
/// `AnimatedOpacity`) while only the panel slides (`AnimatedSlide`,
/// `sheet_panel.dart:124-135`). Both use DS motion tokens and both drop to
/// zero under reduced motion. The keyboard inset lifts the sheet's content
/// box, and is removed from the subtree so a body never adds it twice.
class AppSheetRoute<T> extends PopupRoute<T> {
  AppSheetRoute({
    required this.builder,
    this.detents = const <double>[0.5],
    this.dragHandle = true,
    this.title,
    this.titleSpan,
    this.titleWidget,
    this.titleStyle,
    this.headerActionBuilder,
    this.footerBuilder,
    this.dismissible = true,
    this.closeLabel = DabblerSheet.defaultCloseLabel,
    this.scrimLabel = DabblerSheet.defaultScrimLabel,
    this.detent = DabblerSheetDetent.fractions,
    this.contentMaxFraction = DabblerSheet.defaultContentMaxFraction,
    this.pageBackground = false,
    this.hairlineOutside = false,
    this.showCloseButton = true,
    this.headerDivider = false,
    super.settings,
  });

  final WidgetBuilder builder;
  final List<double> detents;
  final bool dragHandle;
  final String? title;
  final InlineSpan? titleSpan;
  final Widget? titleWidget;
  final DabblerTypeStyle? titleStyle;
  final WidgetBuilder? headerActionBuilder;
  final WidgetBuilder? footerBuilder;
  final bool dismissible;
  final String closeLabel;
  final String scrimLabel;
  final DabblerSheetDetent detent;
  final double contentMaxFraction;
  final bool pageBackground;
  final bool hairlineOutside;
  final bool showCloseButton;
  final bool headerDivider;

  // The wash is the sheet's own [DabblerScrim]; the route barrier stays
  // transparent so there is exactly one scrim.
  @override
  Color? get barrierColor => null;

  // Dismissal runs through [DabblerSheet.onClose] (scrim, Escape, close).
  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => DabblerMotion.slow;

  /// Whether the sheet should be shown as open for [animation]'s state: closed
  /// on the first pushed frame (so the DS sheet animates in from it), open
  /// while pushing or settled, closed again as soon as the pop starts.
  static bool openFor(Animation<double> animation) =>
      switch (animation.status) {
        AnimationStatus.forward => animation.value > 0,
        AnimationStatus.completed => true,
        AnimationStatus.reverse || AnimationStatus.dismissed => false,
      };

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget? headerAction = headerActionBuilder?.call(context);
    final Widget? footer = footerBuilder?.call(context);
    return AnimatedBuilder(
      animation: animation,
      child: builder(context),
      builder: (context, body) {
        final double inset = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: DabblerSheet(
              open: openFor(animation),
              onClose: () => Navigator.of(context).maybePop(),
              detents: detents,
              dragHandle: dragHandle,
              title: title,
              titleSpan: titleSpan,
              titleWidget: titleWidget,
              titleStyle: titleStyle,
              headerAction: headerAction,
              footer: footer,
              dismissible: dismissible,
              closeLabel: closeLabel,
              scrimLabel: scrimLabel,
              detent: detent,
              contentMaxFraction: contentMaxFraction,
              pageBackground: pageBackground,
              hairlineOutside: hairlineOutside,
              showCloseButton: showCloseButton,
              headerDivider: headerDivider,
              child: body,
            ),
          ),
        );
      },
    );
  }

  // No route-level slide: that is what slid the scrim with the panel.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Drop-in replacement for the DS `showDabblerSheet`, with the same parameters,
/// presented through [AppSheetRoute] (stationary fading scrim, sliding panel).
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  List<double> detents = const <double>[0.5],
  bool dragHandle = true,
  String? title,
  InlineSpan? titleSpan,
  Widget? titleWidget,
  DabblerTypeStyle? titleStyle,
  WidgetBuilder? headerActionBuilder,
  WidgetBuilder? footerBuilder,
  bool dismissible = true,
  String closeLabel = DabblerSheet.defaultCloseLabel,
  String scrimLabel = DabblerSheet.defaultScrimLabel,
  DabblerSheetDetent detent = DabblerSheetDetent.fractions,
  double contentMaxFraction = DabblerSheet.defaultContentMaxFraction,
  bool pageBackground = false,
  bool hairlineOutside = false,
  bool showCloseButton = true,
  bool headerDivider = false,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    AppSheetRoute<T>(
      builder: builder,
      detents: detents,
      dragHandle: dragHandle,
      title: title,
      titleSpan: titleSpan,
      titleWidget: titleWidget,
      titleStyle: titleStyle,
      headerActionBuilder: headerActionBuilder,
      footerBuilder: footerBuilder,
      dismissible: dismissible,
      closeLabel: closeLabel,
      scrimLabel: scrimLabel,
      detent: detent,
      contentMaxFraction: contentMaxFraction,
      pageBackground: pageBackground,
      hairlineOutside: hairlineOutside,
      showCloseButton: showCloseButton,
      headerDivider: headerDivider,
    ),
  );
}
