import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/features/social/providers/feed_impressions.dart';

import 'active_event_card.dart';

/// KAN-966: For you in the server's order, except that a card never follows
/// another card and never opens the list (the server spaces them; a news row
/// hidden on this device, or a post removed since, could bring two together).
/// Such a card is dropped and logged; nothing is re-sorted.
List<FeedItem> spaceForYouCards(List<FeedItem> items) {
  final out = <FeedItem>[];
  for (final item in items) {
    if (item is FeedActiveItem && (out.isEmpty || out.last is FeedActiveItem)) {
      debugPrint(
        '[ForYou] card ${item.item.id} would sit '
        '${out.isEmpty ? 'first' : 'next to a card'}; not drawn',
      );
      continue;
    }
    out.add(item);
  }
  return out;
}

/// KAN-966: the Active tab's card inside For you, with no divider above or
/// below it. The first time it is on screen it is recorded as seen
/// ([FeedImpressionTracker]), so the server stops ranking it in.
class HomeForYouCard extends ConsumerStatefulWidget {
  const HomeForYouCard({super.key, required this.card});

  final FeedActiveItem card;

  @override
  ConsumerState<HomeForYouCard> createState() => _HomeForYouCardState();
}

class _HomeForYouCardState extends ConsumerState<HomeForYouCard> {
  ScrollPosition? _position;
  bool _marked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_check);
      _position = position;
      _position?.addListener(_check);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(HomeForYouCard old) {
    super.didUpdateWidget(old);
    if (old.card.item.id != widget.card.item.id) {
      _marked = false;
      _position?.removeListener(_check);
      _position?.addListener(_check);
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  /// Marks the card once any of it is inside the scroll viewport (or, with
  /// no scrollable, inside the view).
  void _check() {
    if (_marked || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    Rect viewport;
    final scrollBox = _position?.context.storageContext.findRenderObject();
    if (scrollBox is RenderBox && scrollBox.hasSize && scrollBox.attached) {
      viewport = scrollBox.localToGlobal(Offset.zero) & scrollBox.size;
    } else {
      viewport = Offset.zero & MediaQuery.sizeOf(context);
    }
    final visible = rect.intersect(viewport);
    if (visible.width <= 0 || visible.height <= 0) return;
    _marked = true;
    _position?.removeListener(_check);
    final e = widget.card.item;
    ref
        .read(feedImpressionTrackerProvider)
        .markSeen(e.entityKind, e.entityId, feedAt: widget.card.feedAt);
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      vertical: DabblerSpacing.space3,
    ),
    child: ActiveEventCard(event: widget.card.item),
  );
}
