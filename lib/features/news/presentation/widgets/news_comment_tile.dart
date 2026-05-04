import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:dabbler/data/models/news/news_comment.dart';

class NewsCommentTile extends StatelessWidget {
  const NewsCommentTile({super.key, required this.comment});

  final NewsComment comment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayName =
        comment.authorDisplayName ?? comment.authorUsername ?? 'User';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(avatarUrl: comment.authorAvatarUrl, displayName: displayName),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeago.format(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, required this.displayName});

  final String? avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: CachedNetworkImageProvider(avatarUrl!),
        backgroundColor: cs.surfaceContainerHighest,
      );
    }
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: cs.primaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}
