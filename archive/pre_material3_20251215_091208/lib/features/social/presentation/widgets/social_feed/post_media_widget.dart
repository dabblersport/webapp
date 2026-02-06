import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PostMediaWidget extends ConsumerStatefulWidget {
  final List<dynamic> media;
  final Function(int)? onMediaTap;
  final Function()? onMediaDoubleTap;
  final bool allowFullScreen;
  final BorderRadius? borderRadius;

  const PostMediaWidget({
    super.key,
    required this.media,
    this.onMediaTap,
    this.onMediaDoubleTap,
    this.allowFullScreen = true,
    this.borderRadius,
  });

  @override
  ConsumerState<PostMediaWidget> createState() => _PostMediaWidgetState();
}

class _PostMediaWidgetState extends ConsumerState<PostMediaWidget> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.media.length == 1) {
      return _buildSingleMedia(context, widget.media.first, 0);
    }

    return _buildMediaCarousel(context);
  }

  Widget _buildSingleMedia(BuildContext context, dynamic media, int index) {
    return GestureDetector(
      onTap: () => widget.onMediaTap?.call(index),
      onDoubleTap: widget.onMediaDoubleTap,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          child: _buildMediaContent(media, index),
        ),
      ),
    );
  }

  Widget _buildMediaCarousel(BuildContext context) {
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          // Media carousel
          ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: widget.media.length,
              itemBuilder: (context, index) {
                final media = widget.media[index];

                return GestureDetector(
                  onTap: () => widget.onMediaTap?.call(index),
                  onDoubleTap: widget.onMediaDoubleTap,
                  child: _buildMediaContent(media, index),
                );
              },
            ),
          ),

          // Media indicators
          if (widget.media.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: _buildMediaIndicators(),
            ),

          // Media counter
          if (widget.media.length > 1)
            Positioned(top: 12, right: 12, child: _buildMediaCounter()),

          // Navigation arrows
          if (widget.media.length > 1) ...[
            // Previous arrow
            if (_currentIndex > 0)
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildNavigationButton(
                    icon: Icons.chevron_left,
                    onTap: () => _previousMedia(),
                  ),
                ),
              ),

            // Next arrow
            if (_currentIndex < widget.media.length - 1)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildNavigationButton(
                    icon: Icons.chevron_right,
                    onTap: () => _nextMedia(),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaContent(dynamic media, int index) {
    switch (media.type?.toLowerCase()) {
      case 'image':
        return _buildImageContent(media);
      case 'video':
        return _buildVideoContent(media);
      case 'gif':
        return _buildGifContent(media);
      default:
        return _buildUnsupportedContent(media);
    }
  }

  Widget _buildImageContent(dynamic media) {
    return InteractiveViewer(
      panEnabled: widget.allowFullScreen,
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 4.0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            media.url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;

              return Container(
                color: Colors.grey.shade200,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorPlaceholder('Failed to load image');
            },
          ),

          // Download overlay
          Positioned(top: 8, right: 8, child: _buildMediaActions(media)),
        ],
      ),
    );
  }

  Widget _buildVideoContent(dynamic media) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video thumbnail or player
        if (media.thumbnailUrl != null)
          Image.network(
            media.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorPlaceholder('Video thumbnail unavailable');
            },
          )
        else
          Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.video_library, color: Colors.white, size: 48),
            ),
          ),

        // Play button overlay
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _playVideo(media),
              icon: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),

        // Video duration
        if (media.duration != null)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatDuration(media.duration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

        // Media actions
        Positioned(top: 8, right: 8, child: _buildMediaActions(media)),
      ],
    );
  }

  Widget _buildGifContent(dynamic media) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          media.url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;

            return Container(
              color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorPlaceholder('Failed to load GIF');
          },
        ),

        // GIF indicator
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'GIF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Media actions
        Positioned(top: 8, right: 8, child: _buildMediaActions(media)),
      ],
    );
  }

  Widget _buildUnsupportedContent(dynamic media) {
    return _buildErrorPlaceholder('Unsupported media type: ${media.type}');
  }

  Widget _buildErrorPlaceholder(String message) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaIndicators() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            widget.media.length,
            (index) => Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == _currentIndex
                    ? Colors.white
                    : Colors.white.withOpacity(0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${_currentIndex + 1}/${widget.media.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildMediaActions(dynamic media) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _downloadMedia(media),
            icon: const Icon(Icons.download, color: Colors.white, size: 20),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            onPressed: () => _shareMedia(media),
            icon: const Icon(Icons.share, color: Colors.white, size: 20),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  void _previousMedia() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextMedia() {
    if (_currentIndex < widget.media.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _playVideo(dynamic media) {
    Navigator.pushNamed(
      context,
      '/media/video-player',
      arguments: {'media': media, 'autoPlay': true},
    );
  }

  void _downloadMedia(dynamic media) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download feature coming soon')),
    );
  }

  void _shareMedia(dynamic media) {
    Navigator.pushNamed(context, '/share/media', arguments: {'media': media});
  }

  String _formatDuration(int? durationInSeconds) {
    if (durationInSeconds == null) return '0:00';

    final minutes = durationInSeconds ~/ 60;
    final seconds = durationInSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Full screen media viewer
class FullScreenMediaViewer extends StatefulWidget {
  final List<dynamic> media;
  final int initialIndex;

  const FullScreenMediaViewer({
    super.key,
    required this.media,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
        },
        child: Stack(
          children: [
            // Media viewer
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: widget.media.length,
              itemBuilder: (context, index) {
                final media = widget.media[index];

                return Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _buildFullScreenMedia(media),
                  ),
                );
              },
            ),

            // Controls overlay
            if (_showControls) ...[
              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentIndex + 1} of ${widget.media.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _shareCurrentMedia(),
                        icon: const Icon(Icons.share, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    left: 16,
                    right: 16,
                    top: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: () => _downloadCurrentMedia(),
                        icon: const Icon(Icons.download, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () => _shareCurrentMedia(),
                        icon: const Icon(Icons.share, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () => _showMediaInfo(),
                        icon: const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Page indicators
              if (widget.media.length > 1)
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          widget.media.length,
                          (index) => Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == _currentIndex
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenMedia(dynamic media) {
    // Handle String URLs directly
    if (media is String) {
      return Image.network(
        media,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;

          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.white, size: 64),
                SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          );
        },
      );
    }

    // Handle Map objects
    final mediaType = media is Map
        ? media['type']?.toString().toLowerCase()
        : media.type?.toLowerCase();
    final mediaUrl = media is Map ? media['url']?.toString() : media.url;
    final thumbnailUrl = media is Map
        ? media['thumbnailUrl']?.toString()
        : media.thumbnailUrl;

    switch (mediaType) {
      case 'image':
        return Image.network(
          mediaUrl ?? '',
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;

            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            );
          },
        );

      case 'video':
        return GestureDetector(
          onTap: () => _playVideo(media),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnailUrl != null)
                Image.network(thumbnailUrl, fit: BoxFit.contain)
              else
                const Center(
                  child: Icon(
                    Icons.video_library,
                    color: Colors.white,
                    size: 64,
                  ),
                ),

              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 80,
                ),
              ),
            ],
          ),
        );

      default:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insert_drive_file, color: Colors.white, size: 64),
              SizedBox(height: 16),
              Text(
                'Unsupported media type',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        );
    }
  }

  void _playVideo(dynamic media) {
    Navigator.pushNamed(
      context,
      '/media/video-player',
      arguments: {'media': media, 'autoPlay': true},
    );
  }

  void _shareCurrentMedia() {
    final media = widget.media[_currentIndex];
    Navigator.pushNamed(context, '/share/media', arguments: {'media': media});
  }

  void _downloadCurrentMedia() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download feature coming soon'),
        backgroundColor: Colors.white24,
      ),
    );
  }

  void _showMediaInfo() {
    final media = widget.media[_currentIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Media Info',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Type: ${media.type ?? 'Unknown'}'),
            if (media.size != null)
              Text('Size: ${_formatFileSize(media.size)}'),
            if (media.duration != null)
              Text('Duration: ${_formatDuration(media.duration)}'),
            if (media.resolution != null)
              Text('Resolution: ${media.resolution}'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(int? durationInSeconds) {
    if (durationInSeconds == null) return '0:00';

    final hours = durationInSeconds ~/ 3600;
    final minutes = (durationInSeconds % 3600) ~/ 60;
    final seconds = durationInSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
