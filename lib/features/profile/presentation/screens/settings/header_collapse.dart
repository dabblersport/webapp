import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// KAN-601: when a pinned top bar leaves its hero tint and shows its title.
///
/// The design derives the threshold from the rendered hero
/// (`Math.max(el.offsetHeight - 52, 18)`, `Profiles.dc.html:818`), so it is
/// measured here, never a fixed device number. The collapsed flag flips with
/// hysteresis so a scroll resting on the edge cannot flicker, and a focused
/// search keeps the compact title up without moving the scroll position.
///
/// The top bar compares the scroll offset with [revealOffset]; handing it an
/// offset that depends on the current state is what makes the flip sticky.
class HeaderCollapseController extends ChangeNotifier {
  HeaderCollapseController(this.scroll) {
    scroll.addListener(_onScroll);
  }

  final ScrollController scroll;

  /// Scroll distance either side of the measured edge before the state flips.
  static const double hysteresis = DabblerSpacing.space2;

  /// The design's floor for a short hero.
  static const double minExtent = DabblerSpacing.space6;

  double _extent = minExtent;
  bool _collapsed = false;
  bool _pinnedCompact = false;

  /// The hero's measured scroll extent, floored.
  double get extent => _extent;

  /// Whether the bar currently shows its title, ignoring the focus override.
  bool get collapsed => _collapsed;

  /// A focused search holds the compact bar: title shown, tint dropped.
  bool get pinnedCompact => _pinnedCompact;

  /// The offset to hand the top bar. Below zero while [pinnedCompact], so the
  /// bar stays compact at any scroll position; otherwise offset to the far
  /// side of the hysteresis band from the current state.
  double get revealOffset {
    if (_pinnedCompact) return -1;
    return _collapsed ? _extent - hysteresis : _extent + hysteresis;
  }

  /// Records the hero's rendered height. Ignores sub-pixel changes.
  void measure(double heroHeight) {
    final double next = heroHeight < minExtent ? minExtent : heroHeight;
    if ((next - _extent).abs() < 0.5) return;
    _extent = next;
    _onScroll();
    notifyListeners();
  }

  set pinnedCompact(bool value) {
    if (_pinnedCompact == value) return;
    _pinnedCompact = value;
    notifyListeners();
  }

  void _onScroll() {
    if (!scroll.hasClients) return;
    final double pixels = scroll.positions.first.pixels;
    final bool next = _collapsed
        ? pixels > _extent - hysteresis
        : pixels > _extent + hysteresis;
    if (next == _collapsed) return;
    _collapsed = next;
    notifyListeners();
  }

  @override
  void dispose() {
    scroll.removeListener(_onScroll);
    super.dispose();
  }
}

/// Reports its child's height to [onHeight] on first layout and on every
/// change after (large text, a long title wrapping, a locale switch).
class MeasuredHeader extends StatefulWidget {
  const MeasuredHeader({
    required this.onHeight,
    required this.child,
    super.key,
  });

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  State<MeasuredHeader> createState() => _MeasuredHeaderState();
}

class _MeasuredHeaderState extends State<MeasuredHeader> {
  void _report() {
    if (!mounted) return;
    final RenderObject? box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) widget.onHeight(box.size.height);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _report());
        return true;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}

/// A sliver that pins [child] under the top bar at the child's own measured
/// height (large text and wrapped labels change it), on the page ground.
class PinnedMeasuredSliver extends StatefulWidget {
  const PinnedMeasuredSliver({required this.child, super.key});

  final Widget child;

  @override
  State<PinnedMeasuredSliver> createState() => _PinnedMeasuredSliverState();
}

class _PinnedMeasuredSliverState extends State<PinnedMeasuredSliver> {
  double _extent = 0;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedDelegate(
        extent: _extent,
        // The delegate hands its child a tight box; an inert scroll view lets
        // the child lay out at its natural height so that height can be read,
        // and clips it to the extent meanwhile.
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: MeasuredHeader(
            onHeight: (double h) {
              if ((h - _extent).abs() < 0.5) return;
              setState(() => _extent = h);
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _PinnedDelegate extends SliverPersistentHeaderDelegate {
  _PinnedDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => DabblerSurface.sunken(child: child);

  @override
  bool shouldRebuild(_PinnedDelegate old) =>
      old.extent != extent || old.child != child;
}
