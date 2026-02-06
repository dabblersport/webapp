import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialSharingWidget extends StatefulWidget {
  final dynamic post;
  final Function(String)? onShare;
  final VoidCallback? onCopyLink;
  final VoidCallback? onShareViaChat;
  final VoidCallback? onCreateStory;
  final String? customMessage;

  const SocialSharingWidget({
    super.key,
    required this.post,
    this.onShare,
    this.onCopyLink,
    this.onShareViaChat,
    this.onCreateStory,
    this.customMessage,
  });

  @override
  State<SocialSharingWidget> createState() => _SocialSharingWidgetState();
}

class _SocialSharingWidgetState extends State<SocialSharingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _messageController.text = widget.customMessage ?? _getDefaultMessage();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildContent(context, theme),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Share Post',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),

        // Post preview
        _buildPostPreview(theme),

        // Custom message input
        _buildMessageInput(theme),

        // Quick share options
        _buildQuickShareOptions(theme),

        // Social platforms
        _buildSocialPlatforms(theme),

        // Additional options
        _buildAdditionalOptions(theme),

        // Bottom padding
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
    );
  }

  Widget _buildPostPreview(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Post thumbnail or avatar
          if (widget.post.media?.isNotEmpty == true)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.post.media.first.thumbnailUrl ??
                    widget.post.media.first.url,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 48,
                    height: 48,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image),
                  );
                },
              ),
            )
          else
            CircleAvatar(
              radius: 24,
              backgroundImage:
                  widget.post.authorAvatar != null &&
                      widget.post.authorAvatar!.isNotEmpty
                  ? NetworkImage(widget.post.authorAvatar!)
                  : null,
              child:
                  widget.post.authorAvatar == null ||
                      widget.post.authorAvatar!.isEmpty
                  ? Text(widget.post.authorName?[0]?.toUpperCase() ?? '?')
                  : null,
            ),

          const SizedBox(width: 12),

          // Post info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.authorName ?? 'Unknown User',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.post.content ?? 'Shared a post',
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add a message (optional)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Write something about this post...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 3,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickShareOptions(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Share',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildQuickShareButton(
                icon: Icons.link,
                label: 'Copy Link',
                color: Colors.blue,
                onTap: _copyPostLink,
              ),
              const SizedBox(width: 16),
              _buildQuickShareButton(
                icon: Icons.message,
                label: 'Via Chat',
                color: Colors.green,
                onTap: widget.onShareViaChat ?? () => _shareViaChat(),
              ),
              const SizedBox(width: 16),
              _buildQuickShareButton(
                icon: Icons.add_circle,
                label: 'Story',
                color: Colors.purple,
                onTap: widget.onCreateStory ?? () => _createStory(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialPlatforms(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share to Social Media',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildSocialPlatformButton(
                platform: 'whatsapp',
                icon: Icons.message,
                label: 'WhatsApp',
                color: Colors.green.shade600,
                onTap: () => _shareToSocialPlatform('whatsapp'),
              ),
              _buildSocialPlatformButton(
                platform: 'twitter',
                icon: Icons.alternate_email,
                label: 'Twitter',
                color: Colors.blue.shade400,
                onTap: () => _shareToSocialPlatform('twitter'),
              ),
              _buildSocialPlatformButton(
                platform: 'facebook',
                icon: Icons.facebook,
                label: 'Facebook',
                color: Colors.blue.shade700,
                onTap: () => _shareToSocialPlatform('facebook'),
              ),
              _buildSocialPlatformButton(
                platform: 'instagram',
                icon: Icons.camera_alt,
                label: 'Instagram',
                color: Colors.pink.shade400,
                onTap: () => _shareToSocialPlatform('instagram'),
              ),
              _buildSocialPlatformButton(
                platform: 'telegram',
                icon: Icons.send,
                label: 'Telegram',
                color: Colors.blue.shade500,
                onTap: () => _shareToSocialPlatform('telegram'),
              ),
              _buildSocialPlatformButton(
                platform: 'linkedin',
                icon: Icons.work,
                label: 'LinkedIn',
                color: Colors.blue.shade800,
                onTap: () => _shareToSocialPlatform('linkedin'),
              ),
              _buildSocialPlatformButton(
                platform: 'discord',
                icon: Icons.chat,
                label: 'Discord',
                color: Colors.deepPurple.shade500,
                onTap: () => _shareToSocialPlatform('discord'),
              ),
              _buildSocialPlatformButton(
                platform: 'more',
                icon: Icons.more_horiz,
                label: 'More',
                color: Colors.grey.shade600,
                onTap: () => _shareToMore(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialPlatformButton({
    required String platform,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalOptions(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'More Options',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Send via Email'),
            onTap: () => _shareViaEmail(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          ListTile(
            leading: const Icon(Icons.sms_outlined),
            title: const Text('Send via SMS'),
            onTap: () => _shareViaSMS(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Share QR Code'),
            onTap: () => _shareQRCode(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ],
      ),
    );
  }

  String _getDefaultMessage() {
    final authorName = widget.post.authorName ?? 'Someone';
    final postType = widget.post.type ?? 'post';

    switch (postType) {
      case 'game_result':
        return 'Check out $authorName\'s game result!';
      case 'achievement':
        return '$authorName just unlocked an achievement!';
      case 'photo':
        return 'Check out this photo from $authorName';
      case 'video':
        return 'Watch this video from $authorName';
      default:
        return 'Check out this post from $authorName';
    }
  }

  void _copyPostLink() {
    final postUrl = 'https://dabbler.app/post/${widget.post.id}';
    Clipboard.setData(ClipboardData(text: postUrl));

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );

    widget.onCopyLink?.call();
  }

  void _shareViaChat() {
    Navigator.pop(context);
    Navigator.pushNamed(
      context,
      '/chat/share-post',
      arguments: {
        'post': widget.post,
        'message': _messageController.text.trim(),
      },
    );

    widget.onShareViaChat?.call();
  }

  void _createStory() {
    Navigator.pop(context);
    Navigator.pushNamed(
      context,
      '/story/create',
      arguments: {
        'sourcePost': widget.post,
        'message': _messageController.text.trim(),
      },
    );

    widget.onCreateStory?.call();
  }

  void _shareToSocialPlatform(String platform) async {
    final postUrl = 'https://dabbler.app/post/${widget.post.id}';
    final message = _messageController.text.trim();
    final fullMessage = message.isNotEmpty ? '$message\n\n$postUrl' : postUrl;

    HapticFeedback.lightImpact();

    try {
      switch (platform) {
        case 'whatsapp':
          await Share.share(fullMessage);
          break;
        case 'twitter':
          final twitterText = Uri.encodeComponent(fullMessage);
          final twitterUrl =
              'https://twitter.com/intent/tweet?text=$twitterText';
          await _launchExternalUrl(twitterUrl);
          break;
        case 'facebook':
          final facebookUrl =
              'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(postUrl)}';
          await _launchExternalUrl(facebookUrl);
          break;
        case 'telegram':
          final telegramText = Uri.encodeComponent(fullMessage);
          final telegramUrl =
              'https://t.me/share/url?url=${Uri.encodeComponent(postUrl)}&text=$telegramText';
          await _launchExternalUrl(telegramUrl);
          break;
        case 'linkedin':
          final linkedinUrl =
              'https://www.linkedin.com/sharing/share-offsite/?url=${Uri.encodeComponent(postUrl)}';
          await _launchExternalUrl(linkedinUrl);
          break;
        default:
          await Share.share(fullMessage);
      }

      widget.onShare?.call(platform);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shared to ${platform.toUpperCase()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share to ${platform.toUpperCase()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareToMore() async {
    final postUrl = 'https://dabbler.app/post/${widget.post.id}';
    final message = _messageController.text.trim();
    final fullMessage = message.isNotEmpty ? '$message\n\n$postUrl' : postUrl;

    try {
      await Share.share(fullMessage);
      widget.onShare?.call('system');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to share'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareViaEmail() {
    final postUrl = 'https://dabbler.app/post/${widget.post.id}';
    final message = _messageController.text.trim();
    final subject =
        'Check out this post from ${widget.post.authorName ?? 'Dabbler'}';
    final body = message.isNotEmpty
        ? '$message\n\n$postUrl'
        : 'I thought you might find this interesting:\n\n$postUrl';

    final emailUrl =
        'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';

    _launchExternalUrl(emailUrl);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening email app...')));

    widget.onShare?.call('email');
  }

  void _shareViaSMS() {
    final postUrl = 'https://dabbler.app/post/${widget.post.id}';
    final message = _messageController.text.trim();
    final fullMessage = message.isNotEmpty
        ? '$message $postUrl'
        : 'Check this out: $postUrl';

    final smsUrl = 'sms:?body=${Uri.encodeComponent(fullMessage)}';

    _launchExternalUrl(smsUrl);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening messages app...')));

    widget.onShare?.call('sms');
  }

  Future<void> _launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open link'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareQRCode() {
    Navigator.pop(context);
    Navigator.pushNamed(
      context,
      '/share/qr-code',
      arguments: {
        'url': 'https://dabbler.app/post/${widget.post.id}',
        'title': 'Share Post',
        'description': widget.post.content ?? 'Check out this post',
      },
    );

    widget.onShare?.call('qr');
  }
}

/// Compact share button widget
class CompactShareButton extends StatelessWidget {
  final dynamic post;
  final Function(String)? onShare;

  const CompactShareButton({super.key, required this.post, this.onShare});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showShareDialog(context),
      icon: const Icon(Icons.share_outlined),
      tooltip: 'Share',
    );
  }

  void _showShareDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: SocialSharingWidget(post: post, onShare: onShare),
        ),
      ),
    );
  }
}
