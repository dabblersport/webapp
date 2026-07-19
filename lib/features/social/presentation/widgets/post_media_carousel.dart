import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Threads-style media strip for a post.
///
/// One image renders full-width (16:9, rounded). Two or more render as a
/// horizontally scrollable carousel of rounded cards with the next card
/// peeking, like Instagram Threads. Non-image entries in [media] are skipped.
class PostMediaCarousel extends StatelessWidget {
  const PostMediaCarousel({
    super.key,
    required this.media,
    this.borderRadius = 12,
    this.carouselHeight = 240,
    this.padding,
  });

  /// Raw `post.media` list — entries are either URL strings or maps with a
  /// `url` / `uri` / `src` key.
  final List<dynamic> media;
  final double borderRadius;
  final double carouselHeight;

  /// Outer padding. A single image is inset by it; a carousel keeps it as
  /// list content padding so images scroll edge-to-edge underneath it.
  final EdgeInsetsGeometry? padding;

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
    final cs = Theme.of(context).colorScheme;

    if (urls.length == 1) {
      final image = GestureDetector(
        onTap: () => _MediaFullscreenViewer.open(context, urls, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _networkImage(urls.first, cs),
          ),
        ),
      );
      return padding == null ? image : Padding(padding: padding!, child: image);
    }

    final itemWidth = MediaQuery.sizeOf(context).width * 0.72;
    return SizedBox(
      height: carouselHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        physics: const BouncingScrollPhysics(),
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _MediaFullscreenViewer.open(context, urls, index),
            child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: SizedBox(
              width: itemWidth,
              height: carouselHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _networkImage(urls[index], cs),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${index + 1}/${urls.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  static Widget _networkImage(String url, ColorScheme cs) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: cs.surfaceContainerHigh,
        child: Icon(Iconsax.gallery_slash_copy, color: cs.onSurfaceVariant),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: cs.surfaceContainerHigh,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen media viewer with Twitter/X-style gestures:
///   • swipe left/right between images (starts at the tapped one)
///   • pinch or double-tap to zoom in/out
///   • drag up or down to dismiss — the image follows the finger while the
///     backdrop fades; release past the threshold (or fling) to close.
class _MediaFullscreenViewer extends StatefulWidget {
  const _MediaFullscreenViewer({
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  static void open(BuildContext context, List<String> urls, int index) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) =>
            _MediaFullscreenViewer(urls: urls, initialIndex: index),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<_MediaFullscreenViewer> createState() => _MediaFullscreenViewerState();
}

class _MediaFullscreenViewerState extends State<_MediaFullscreenViewer>
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
          _dragOffset = _dragOffset * (1 - Curves.easeOut.transform(_snapBack.value));
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
    final shouldDismiss = _dragOffset.abs() > _dismissDistance ||
        velocity.abs() > _dismissVelocity;
    if (shouldDismiss) {
      Navigator.of(context).pop();
    } else if (_dragOffset != 0) {
      _snapBack.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _dismissProgress;
    final chromeOpacity = (1 - progress * 2.5).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
        onVerticalDragEnd: _zoomed ? null : _onDragEnd,
        child: Stack(
          children: [
            // Backdrop fades as the image is dragged away (Twitter behavior).
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 1 - progress * 0.8),
              ),
            ),
            Transform.translate(
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
            // Top bar: counter + close. Fades out while dragging to dismiss.
            Opacity(
              opacity: chromeOpacity,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      if (widget.urls.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_index + 1}/${widget.urls.length}',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One zoomable page: pinch to zoom (up to 4x), double-tap to toggle between
/// fit and 2.5x centered on the tap point. Reports zoom state upward so the
/// pager and drag-to-dismiss stay out of the way while zoomed.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.url, required this.onZoomChanged});

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  late final AnimationController _zoomAnim;
  Animation<Matrix4>? _zoomTween;
  TapDownDetails? _doubleTapDetails;

  static const double _doubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    _zoomAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_zoomTween != null) {
          _transform.value = _zoomTween!.value;
          _notifyZoom();
        }
      });
  }

  @override
  void dispose() {
    _zoomAnim.dispose();
    _transform.dispose();
    super.dispose();
  }

  bool get _isZoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  void _notifyZoom() => widget.onZoomChanged(_isZoomed);

  void _handleDoubleTap() {
    final Matrix4 target;
    if (_isZoomed) {
      target = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ??
          MediaQuery.sizeOf(context).center(Offset.zero);
      target = Matrix4.identity()
        ..translateByDouble(
          -position.dx * (_doubleTapScale - 1),
          -position.dy * (_doubleTapScale - 1),
          0,
          1,
        )
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
    }
    _zoomTween = Matrix4Tween(begin: _transform.value, end: target).animate(
      CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOut),
    );
    _zoomAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        maxScale: 4,
        // Pan only matters while zoomed; leaving it off at 1x lets the
        // vertical drag-to-dismiss gesture reach the parent detector.
        panEnabled: _isZoomed,
        onInteractionEnd: (_) => _notifyZoom(),
        onInteractionUpdate: (_) => _notifyZoom(),
        child: Center(
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Iconsax.gallery_slash_copy,
              color: Colors.white54,
              size: 48,
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
