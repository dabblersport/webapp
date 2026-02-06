import 'package:flutter/material.dart';

class PostContentWidget extends StatelessWidget {
  final String content;
  final List<dynamic>? media;
  final List<String>? sports;
  final List<String>? mentions;
  final List<String>? hashtags;
  final Function(int)? onMediaTap;
  final Function(String)? onMentionTap;
  final Function(String)? onHashtagTap;

  const PostContentWidget({
    super.key,
    required this.content,
    this.media,
    this.sports,
    this.mentions,
    this.hashtags,
    this.onMediaTap,
    this.onMentionTap,
    this.onHashtagTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post text content
        if (content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              content,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
          ),

        // Sports tags
        if (sports != null && sports!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: sports!
                  .map((sport) => _buildSportChip(theme, sport))
                  .toList(),
            ),
          ),

        // Media grid
        if (media != null && media!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildMediaGrid(theme),
          ),

        // Mentions and hashtags
        if ((mentions != null && mentions!.isNotEmpty) ||
            (hashtags != null && hashtags!.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildTags(theme),
          ),
      ],
    );
  }

  Widget _buildSportChip(ThemeData theme, String sport) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        sport,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMediaGrid(ThemeData theme) {
    if (media!.length == 1) {
      return _buildSingleMedia(theme, media![0], 0);
    } else if (media!.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildSingleMedia(theme, media![0], 0)),
          const SizedBox(width: 4),
          Expanded(child: _buildSingleMedia(theme, media![1], 1)),
        ],
      );
    } else if (media!.length == 3) {
      return Column(
        children: [
          _buildSingleMedia(theme, media![0], 0),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _buildSingleMedia(theme, media![1], 1)),
              const SizedBox(width: 4),
              Expanded(child: _buildSingleMedia(theme, media![2], 2)),
            ],
          ),
        ],
      );
    } else if (media!.length == 4) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildSingleMedia(theme, media![0], 0)),
              const SizedBox(width: 4),
              Expanded(child: _buildSingleMedia(theme, media![1], 1)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _buildSingleMedia(theme, media![2], 2)),
              const SizedBox(width: 4),
              Expanded(child: _buildSingleMedia(theme, media![3], 3)),
            ],
          ),
        ],
      );
    } else {
      // More than 4 media items
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildSingleMedia(theme, media![0], 0)),
              const SizedBox(width: 4),
              Expanded(child: _buildSingleMedia(theme, media![1], 1)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _buildSingleMedia(theme, media![2], 2)),
              const SizedBox(width: 4),
              Expanded(
                child: Stack(
                  children: [
                    _buildSingleMedia(theme, media![3], 3),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '+${media!.length - 4}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildSingleMedia(ThemeData theme, dynamic mediaItem, int index) {
    // Handle both String URLs and Map objects
    String mediaUrl;
    String? mediaType;

    if (mediaItem is String) {
      mediaUrl = mediaItem;
      mediaType = null;
    } else if (mediaItem is Map) {
      mediaUrl = mediaItem['url']?.toString() ?? '';
      mediaType = mediaItem['type']?.toString();
    } else {
      mediaUrl = mediaItem.toString();
      mediaType = null;
    }

    final isImage =
        mediaType == 'image' ||
        mediaUrl.contains('image') ||
        mediaUrl.contains('jpg') ||
        mediaUrl.contains('png') ||
        mediaUrl.contains('jpeg') ||
        mediaUrl.contains('gif') ||
        mediaUrl.contains('webp');

    return GestureDetector(
      onTap: () => onMediaTap?.call(index),
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isImage && mediaUrl.isNotEmpty
              ? Image.network(
                  mediaUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildMediaPlaceholder(theme),
                )
              : _buildMediaPlaceholder(theme),
        ),
      ),
    );
  }

  Widget _buildMediaPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image,
        color: theme.colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }

  Widget _buildTags(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        // Mentions
        if (mentions != null)
          ...mentions!.map((mention) => _buildMentionChip(theme, mention)),

        // Hashtags
        if (hashtags != null)
          ...hashtags!.map((hashtag) => _buildHashtagChip(theme, hashtag)),
      ],
    );
  }

  Widget _buildMentionChip(ThemeData theme, String mention) {
    return GestureDetector(
      onTap: () => onMentionTap?.call(mention),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          mention,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHashtagChip(ThemeData theme, String hashtag) {
    return GestureDetector(
      onTap: () => onHashtagTap?.call(hashtag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          hashtag,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onTertiaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
