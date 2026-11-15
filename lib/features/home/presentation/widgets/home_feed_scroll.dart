import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// KAN-956: whether the Home header should show for the feed's scroll
/// [position] (`Home Feed.dc.html`, the header's `max-height:{{ hdrEn }}`
/// driven by the feed's `onScroll`).
///
/// At (or above) the top it shows; a user scroll down hides it and a user
/// scroll up brings it back. `null` means "leave it as it is": a programmatic
/// jump or an idle position carries no direction.
bool? homeHeaderShownFor(ScrollPosition position) {
  if (position.pixels <= position.minScrollExtent) return true;
  return switch (position.userScrollDirection) {
    ScrollDirection.reverse => false,
    ScrollDirection.forward => true,
    ScrollDirection.idle => null,
  };
}

/// KAN-956: the Home header region under a fixed status bar.
///
/// The status-bar inset stays put (the frame's 50px status row never folds);
/// below it [child] folds its height to nothing while [shown] is false and
/// unfolds when it turns true, over [DabblerMotion.slow] (200ms) ease-out in
/// both directions — the frame's `transition:max-height 200ms ease-out`.
/// Folding keeps the header's subtree alive, so its state survives.
class HomeCollapsingHeader extends StatefulWidget {
  /// The header region; [child] is the top bar.
  const HomeCollapsingHeader({
    super.key,
    required this.shown,
    required this.child,
  });

  /// Whether the header is unfolded.
  final bool shown;

  /// The top bar. It must not pad the status bar itself: this widget does.
  final Widget child;

  /// Finds the folding region in a test.
  static const Key regionKey = ValueKey<String>('home-collapsing-header');

  @override
  State<HomeCollapsingHeader> createState() => _HomeCollapsingHeaderState();
}

class _HomeCollapsingHeaderState extends State<HomeCollapsingHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.shown ? 1 : 0,
  );
  late final CurvedAnimation _fold = CurvedAnimation(
    parent: _controller,
    curve: DabblerMotion.easeOut,
    reverseCurve: DabblerMotion.easeOut.flipped,
  );

  @override
  void didUpdateWidget(HomeCollapsingHeader old) {
    super.didUpdateWidget(old);
    if (old.shown == widget.shown) return;
    _controller.duration = DabblerMotion.durationOf(
      context,
      DabblerMotion.slow,
    );
    widget.shown ? _controller.forward() : _controller.reverse();
  }

  @override
  void dispose() {
    _fold.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: SizeTransition(
          key: HomeCollapsingHeader.regionKey,
          sizeFactor: _fold,
          // Folds from the bottom edge up, as `max-height` clips.
          alignment: Alignment.topCenter,
          child: widget.child,
        ),
      ),
    );
  }
}
