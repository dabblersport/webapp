import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Media strip for a post: one image renders full-width (16:9). Two or more
/// render as a horizontally scrolling list of [DabblerImage]s with the next one
/// peeking. Non-image entries in [media] are skipped. Tapping an image opens
/// the full-screen viewer.
class PostMediaCarousel extends StatelessWidget {
  const PostMediaCarousel({
    super.key,
    required this.media,
    this.carouselHeight = 240,
    this.padding,
  });

  /// Raw `post.media` list — entries are either URL strings or maps with a
  /// `url` / `uri` / `src` key.
  final List<dynamic> media;
  final double carouselHeight;

  /// Outer padding. A single image is inset by it; a carousel keeps it as
  /// list content padding so images scroll edge-to-edge underneath it.
  final EdgeInsetsGeometry? padding;

  /// Opens the full-screen viewer at [index] — the tap behaviour of a media
  /// tile, for callers that draw their own tiles.
  static void openViewer(BuildContext context, List<String> urls, int index) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) =>
            MediaViewer(urls: urls, initialIndex: index),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Extracts all renderable image URLs from a raw media list.
  static List<String> imageUrls(List<dynamic> media) {
    final urls = <String>[];
    for (final entry in media) {
      String? url;
      if (entry is Map) {
        url = (entry['url'] ?? entry['uri'] ?? entry['src'])?.toString();
      } else if (entry is String) {
        url = entry;
      }
      if (url != null && url.startsWith('http')) urls.add(url);
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final urls = imageUrls(media);
    if (urls.isEmpty) return const SizedBox.shrink();

    if (urls.length == 1) {
      return Padding(
        padding: padding ?? EdgeInsets.zero,
        child: DabblerImage(
          url: urls.first,
          aspectRatio: 16 / 9,
          radius: DabblerRadius.lgAll,
          onTap: () => openViewer(context, urls, 0),
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width * 0.72;
    return SizedBox(
      height: carouselHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ?? EdgeInsets.zero,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: DabblerSpacing.space2),
        itemBuilder: (_, i) => DabblerImage(
          url: urls[i],
          width: width,
          height: carouselHeight,
          radius: DabblerRadius.lgAll,
          overlay: Align(
            alignment: AlignmentDirectional.topEnd,
            child: Padding(
              padding: const EdgeInsets.all(DabblerSpacing.space2),
              child: DabblerBadge(label: '${i + 1}/${urls.length}'),
            ),
          ),
          onTap: () => openViewer(context, urls, i),
        ),
      ),
    );
  }
}

/// Full-screen media pager: swipe between images, pinch to zoom, drag up or
/// down to dismiss (the image follows the finger and the header fades; release
/// past the threshold, or fling, to close), or close from the top bar.
class MediaViewer extends StatefulWidget {
  const MediaViewer({super.key, required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _snapBack;
  late int _index;

  /// Vertical finger offset while drag-dismissing.
  double _dragOffset = 0;
  bool _zoomed = false;

  static const double _dismissDistance = 130;
  static const double _dismissVelocity = 800;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _snapBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        setState(() {
          _dragOffset =
              _dragOffset * (1 - Curves.easeOut.transform(_snapBack.value));
        });
      });
  }

  @override
  void dispose() {
    _snapBack.dispose();
    _pageController.dispose();
    super.dispose();
  }

  double get _dismissProgress {
    final h = MediaQuery.sizeOf(context).height;
    return (_dragOffset.abs() / (h * 0.5)).clamp(0.0, 1.0);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_zoomed || _snapBack.isAnimating) return;
    setState(() => _dragOffset += details.delta.dy);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_zoomed) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final shouldDismiss =
        _dragOffset.abs() > _dismissDistance || velocity.abs() > _dismissVelocity;
    if (shouldDismiss) {
      Navigator.of(context).pop();
    } else if (_dragOffset != 0) {
      _snapBack.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.urls.length > 1;
    final progress = _dismissProgress;
    return DabblerPage(
      topBar: Opacity(
        opacity: (1 - progress * 2.5).clamp(0.0, 1.0),
        child: DabblerNavigationTopBar.titled(
          title: many ? '${_index + 1}/${widget.urls.length}' : null,
          onBack: () => Navigator.of(context).maybePop(),
          backLabel: 'Close',
        ),
      ),
      body: GestureDetector(
        onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
        onVerticalDragEnd: _zoomed ? null : _onDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: Transform.scale(
            scale: 1 - progress * 0.15,
            child: PageView.builder(
              controller: _pageController,
              // While zoomed, the image owns pan/drag gestures.
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) => _ZoomableImage(
                url: widget.urls[index],
                onZoomChanged: (zoomed) {
                  if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One zoomable page; reports zoom state upward so the pager and
/// drag-to-dismiss stay out of the way while zoomed.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.url, required this.onZoomChanged});

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _controller = TransformationController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(
      () => widget.onZoomChanged(_controller.value.getMaxScaleOnAxis() > 1.01),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    transformationController: _controller,
    maxScale: 4,
    // `contain`: the whole image shows, as the pre-migration viewer did.
    child: DabblerImage(
      url: widget.url,
      radius: BorderRadius.zero,
      fit: BoxFit.contain,
    ),
  );
}
