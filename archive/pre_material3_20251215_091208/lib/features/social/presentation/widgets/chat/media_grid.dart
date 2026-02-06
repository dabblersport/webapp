import 'package:flutter/material.dart';

class MediaGrid extends StatelessWidget {
  final List<dynamic> media;
  final Function(dynamic)? onMediaTap;
  final Function(dynamic)? onMediaLongPress;

  const MediaGrid({
    super.key,
    required this.media,
    this.onMediaTap,
    this.onMediaLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final mediaItem = media[index];
        return _MediaGridItem(
          media: mediaItem,
          onTap: onMediaTap != null ? () => onMediaTap!(mediaItem) : null,
          onLongPress: onMediaLongPress != null
              ? () => onMediaLongPress!(mediaItem)
              : null,
        );
      },
    );
  }
}

class _MediaGridItem extends StatelessWidget {
  final dynamic media;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _MediaGridItem({required this.media, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media content
              if (media.type == 'image')
                Image.network(
                  media.thumbnailUrl ?? media.url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.broken_image,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                )
              else if (media.type == 'video')
                Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      media.thumbnailUrl ?? media.url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.broken_image,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                )
              else
                Center(
                  child: Icon(
                    _getFileIcon(media.type),
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 32,
                  ),
                ),

              // Tap overlay
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }
}
