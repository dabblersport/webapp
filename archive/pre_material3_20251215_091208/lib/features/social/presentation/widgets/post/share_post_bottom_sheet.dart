import 'package:flutter/material.dart';

class SharePostBottomSheet extends StatelessWidget {
  final dynamic post;

  const SharePostBottomSheet({super.key, this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Share Post',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Share options
          _buildShareOption(
            theme,
            icon: Icons.copy,
            title: 'Copy Link',
            subtitle: 'Copy the post link to clipboard',
            onTap: () => _copyLink(context),
          ),

          _buildShareOption(
            theme,
            icon: Icons.share,
            title: 'Share to Feed',
            subtitle: 'Share this post to your own feed',
            onTap: () => _shareToFeed(context),
          ),

          _buildShareOption(
            theme,
            icon: Icons.message,
            title: 'Send in Message',
            subtitle: 'Send this post in a private message',
            onTap: () => _sendInMessage(context),
          ),

          _buildShareOption(
            theme,
            icon: Icons.group,
            title: 'Share to Group',
            subtitle: 'Share this post to a group chat',
            onTap: () => _shareToGroup(context),
          ),

          _buildShareOption(
            theme,
            icon: Icons.public,
            title: 'Share Externally',
            subtitle: 'Share to other apps',
            onTap: () => _shareExternally(context),
          ),

          const SizedBox(height: 16),

          // Cancel button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareOption(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _copyLink(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
  }

  void _shareToFeed(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Post shared to your feed')));
  }

  void _sendInMessage(BuildContext context) {
    Navigator.pop(context);
    Navigator.pushNamed(context, '/social/chat');
  }

  void _shareToGroup(BuildContext context) {
    Navigator.pop(context);
    Navigator.pushNamed(context, '/social/groups');
  }

  void _shareExternally(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening external share options...')),
    );
  }
}
