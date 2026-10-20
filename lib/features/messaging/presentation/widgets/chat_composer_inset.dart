import 'package:flutter/widgets.dart';

/// Lifts the chat composer clear of the home indicator / navigation bar.
///
/// `DabblerPage` skips the bottom safe area whenever it has a `bottomBar`,
/// on the contract that a bottom bar pads itself (as
/// `DabblerNavigationBottomBar` does). `DabblerChatComposer` does not, so the
/// composer sat against the screen edge (KAN-578).
///
/// The inset is read from `viewPadding`, not `padding`: `DabblerPage` lifts
/// its bar by the keyboard and then removes the view insets for its children,
/// which reduces `viewPadding.bottom` by the keyboard height (to 0 on every
/// real device). So with the keyboard open the composer sits directly on the
/// keyboard, and with it closed it clears the system inset exactly once. The
/// composer's own `--space-4` bottom padding is the comfortable gap on top.
class ChatComposerInset extends StatelessWidget {
  const ChatComposerInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom),
    child: child,
  );
}

/// Keeps the thread on the latest message when its viewport shrinks.
///
/// `DabblerMessageThread` anchors to the bottom only when its items change,
/// so opening the keyboard (which shrinks the body) left the newest message
/// under the composer. When the reader was at the latest message before the
/// viewport shrank, this re-pins it after the frame (KAN-578).
class ChatStickToLatest extends StatefulWidget {
  const ChatStickToLatest({super.key, required this.child});

  final Widget child;

  @override
  State<ChatStickToLatest> createState() => _ChatStickToLatestState();
}

class _ChatStickToLatestState extends State<ChatStickToLatest> {
  ScrollMetrics? _last;

  bool _onMetrics(ScrollMetricsNotification n) {
    final prev = _last;
    final now = n.metrics;
    _last = now.copyWith();
    if (n.depth != 0 || now.axis != Axis.vertical || prev == null) {
      return false;
    }
    final wasAtLatest = prev.pixels >= prev.maxScrollExtent - 1;
    if (wasAtLatest && now.viewportDimension < prev.viewportDimension) {
      final position = Scrollable.of(n.context).position;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && position.hasPixels) {
          position.jumpTo(position.maxScrollExtent);
        }
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: _onMetrics,
        child: widget.child,
      );
}
