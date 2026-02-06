import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/widgets/custom_avatar.dart';
import '../../../../../themes/app_colors.dart';
import '../../../../../themes/app_text_styles.dart';
import '../../../../../utils/formatters/time_formatter.dart';
import '../../../../../utils/enums/social_enums.dart'; // For MessageType
// Removed broken image/video widget imports
import 'package:dabbler/data/models/social/chat_message_model.dart';
import 'package:dabbler/data/models/authentication/user_model.dart';
import 'message_status_indicator.dart';

/// Message bubble types
enum MessageBubbleType { sent, received, system }

/// A reusable chat bubble widget for displaying messages
/// with different styling for sent/received messages
class ChatBubble extends ConsumerStatefulWidget {
  final ChatMessageModel message;
  final UserModel? sender;
  final bool isConsecutive;
  final bool showAvatar;
  final bool showTimestamp;
  final bool showReadReceipts;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;
  final VoidCallback? onReact;
  final Function(String)? onCopyText;
  final Function(String)? onOpenLink;
  final EdgeInsetsGeometry? margin;

  const ChatBubble({
    super.key,
    required this.message,
    this.sender,
    this.isConsecutive = false,
    this.showAvatar = true,
    this.showTimestamp = true,
    this.showReadReceipts = true,
    this.onTap,
    this.onLongPress,
    this.onReply,
    this.onReact,
    this.onCopyText,
    this.onOpenLink,
    this.margin,
  });

  @override
  ConsumerState<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends ConsumerState<ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _slideAnimation =
        Tween<Offset>(
          begin: widget.message.senderId == 'current_user'
              ? const Offset(0.3, 0)
              : const Offset(-0.3, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  MessageBubbleType get _bubbleType {
    if (widget.message.messageType == MessageType.system) {
      return MessageBubbleType.system;
    }
    return widget.message.senderId == 'current_user'
        ? MessageBubbleType.sent
        : MessageBubbleType.received;
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    _showMessageOptions();
    widget.onLongPress?.call();
  }

  void _showMessageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildMessageOptionsSheet(),
    );
  }

  Widget _buildMessageOptionsSheet() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          if (widget.message.content.isNotEmpty)
            _buildOptionTile(
              icon: Icons.copy,
              title: 'Copy Text',
              onTap: () {
                Navigator.pop(context);
                widget.onCopyText?.call(widget.message.content);
                Clipboard.setData(ClipboardData(text: widget.message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Text copied to clipboard')),
                );
              },
            ),
          _buildOptionTile(
            icon: Icons.reply,
            title: 'Reply',
            onTap: () {
              Navigator.pop(context);
              widget.onReply?.call();
            },
          ),
          _buildOptionTile(
            icon: Icons.emoji_emotions,
            title: 'React',
            onTap: () {
              Navigator.pop(context);
              widget.onReact?.call();
            },
          ),
          if (widget.message.senderId == 'current_user')
            _buildOptionTile(
              icon: Icons.delete,
              title: 'Delete',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle delete
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bubbleType == MessageBubbleType.system) {
      return _buildSystemMessage();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin:
                  widget.margin ??
                  EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: widget.isConsecutive ? 2 : 8,
                  ),
              child: Row(
                mainAxisAlignment: _bubbleType == MessageBubbleType.sent
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_bubbleType == MessageBubbleType.received) ...[
                    _buildAvatar(),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: _bubbleType == MessageBubbleType.sent
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        _buildMessageBubble(),
                        if (widget.showTimestamp || widget.showReadReceipts)
                          _buildMessageInfo(),
                      ],
                    ),
                  ),
                  if (_bubbleType == MessageBubbleType.sent) ...[
                    const SizedBox(width: 8),
                    _buildMessageStatus(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar() {
    if (!widget.showAvatar || widget.isConsecutive || widget.sender == null) {
      return SizedBox(width: 32); // Placeholder for alignment
    }

    return CustomAvatar(imageUrl: widget.sender?.profileImageUrl, radius: 16);
  }

  Widget _buildMessageBubble() {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: _handleLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: _buildBubbleDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // if (widget.message.replyTo != null)
              //   _buildReplyPreview(),
              _buildMessageContent(),
              // if (widget.message.reactions?.isNotEmpty == true)
              //   _buildReactions(),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBubbleDecoration() {
    final isSent = _bubbleType == MessageBubbleType.sent;

    return BoxDecoration(
      color: isSent ? AppColors.primary : Theme.of(context).cardColor,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isSent ? 18 : 4),
        bottomRight: Radius.circular(isSent ? 4 : 18),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildMessageContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message.messageType == MessageType.text)
            _buildTextContent(),
          if (widget.message.messageType == MessageType.image)
            _buildImageContent(),
          if (widget.message.messageType == MessageType.video)
            _buildVideoContent(),
          if (widget.message.messageType == MessageType.file)
            _buildFileContent(),
          if (widget.message.messageType == MessageType.audio)
            _buildVoiceContent(),
          if (_hasLinks()) _buildLinkPreview(),
        ],
      ),
    );
  }

  Widget _buildTextContent() {
    return SelectableText(
      widget.message.content,
      style: AppTextStyles.bodyMedium.copyWith(
        color: _bubbleType == MessageBubbleType.sent
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
      ),
      onTap: () => widget.onTap?.call(),
    );
  }

  Widget _buildImageContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: widget.message.mediaAttachments.isNotEmpty
          ? Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.image, size: 48)),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildVideoContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: widget.message.mediaAttachments.isNotEmpty
          ? Icon(Icons.videocam, size: 48)
          : const SizedBox.shrink(),
    );
  }

  Widget _buildFileContent() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file,
            color: _bubbleType == MessageBubbleType.sent
                ? Colors.white
                : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.message.mediaAttachments.isNotEmpty
                      ? widget.message.mediaAttachments.first.name
                      : 'File',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _bubbleType == MessageBubbleType.sent
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.message.mediaAttachments.isNotEmpty)
                  Text(
                    _formatFileSize(widget.message.mediaAttachments.first.size),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _bubbleType == MessageBubbleType.sent
                          ? Colors.white.withOpacity(0.7)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow,
            color: _bubbleType == MessageBubbleType.sent
                ? Colors.white
                : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color:
                    (_bubbleType == MessageBubbleType.sent
                            ? Colors.white
                            : AppColors.primary)
                        .withOpacity(0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '0:00',
            style: AppTextStyles.bodySmall.copyWith(
              color: _bubbleType == MessageBubbleType.sent
                  ? Colors.white.withOpacity(0.8)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasLinks() {
    final urlRegex = RegExp(
      r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+',
    );
    return urlRegex.hasMatch(widget.message.content);
  }

  Widget _buildLinkPreview() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 120,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: const Icon(Icons.link, size: 32),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Link Preview Title',
            style: AppTextStyles.bodyMedium.copyWith(
              color: _bubbleType == MessageBubbleType.sent
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Link description preview...',
            style: AppTextStyles.bodySmall.copyWith(
              color: _bubbleType == MessageBubbleType.sent
                  ? Colors.white.withOpacity(0.7)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showTimestamp)
            Text(
              TimeFormatter.format(widget.message.sentAt),
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          if (widget.showReadReceipts &&
              _bubbleType == MessageBubbleType.sent) ...[
            const SizedBox(width: 4),
            Text(
              'Read by ${widget.message.readBy.length}',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageStatus() {
    if (_bubbleType != MessageBubbleType.sent) {
      return const SizedBox(width: 20);
    }

    return MessageStatusIndicator(
      status: 'sent',
      readCount: widget.message.readBy.length,
      size: 16,
    );
  }

  Widget _buildSystemMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            widget.message.content,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // Removed unused _showFullScreenMedia method

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Compact version for previews
class CompactChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final UserModel? sender;

  const CompactChatBubble({super.key, required this.message, this.sender});

  @override
  Widget build(BuildContext context) {
    return ChatBubble(
      message: message,
      sender: sender,
      showAvatar: false,
      showTimestamp: false,
      showReadReceipts: false,
      margin: const EdgeInsets.symmetric(vertical: 2),
    );
  }
}
