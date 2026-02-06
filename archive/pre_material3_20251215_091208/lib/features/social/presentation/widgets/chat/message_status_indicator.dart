import 'package:flutter/material.dart';
import '../../../../../themes/app_colors.dart';
import '../../../../../themes/app_text_styles.dart';

/// Message delivery status types
enum MessageStatus { sending, sent, delivered, read, failed }

/// A widget for displaying message status indicators
/// including sent, delivered, read, and failed states
class MessageStatusIndicator extends StatefulWidget {
  final String status;
  final int readCount;
  final double size;
  final Color? color;
  final bool showReadCount;
  final bool animateSending;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry? padding;

  const MessageStatusIndicator({
    super.key,
    required this.status,
    this.readCount = 0,
    this.size = 16,
    this.color,
    this.showReadCount = true,
    this.animateSending = true,
    this.onRetry,
    this.padding,
  });

  @override
  State<MessageStatusIndicator> createState() => _MessageStatusIndicatorState();
}

class _MessageStatusIndicatorState extends State<MessageStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void didUpdateWidget(MessageStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start or stop animations based on status
    if (widget.status != oldWidget.status) {
      if (widget.status == 'sending' && widget.animateSending) {
        _animationController.repeat();
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Start animation if status is sending
    if (widget.status == 'sending' && widget.animateSending) {
      _animationController.repeat();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  MessageStatus get _messageStatus {
    switch (widget.status) {
      case 'sending':
        return MessageStatus.sending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  Color _getStatusColor() {
    if (widget.color != null) return widget.color!;

    switch (_messageStatus) {
      case MessageStatus.sending:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case MessageStatus.sent:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case MessageStatus.delivered:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case MessageStatus.read:
        return AppColors.primary;
      case MessageStatus.failed:
        return Colors.red;
    }
  }

  IconData _getStatusIcon() {
    switch (_messageStatus) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
    }
  }

  Widget _buildStatusIcon() {
    Widget icon = Icon(
      _getStatusIcon(),
      size: widget.size,
      color: _getStatusColor(),
    );

    // Add animation for sending status
    if (_messageStatus == MessageStatus.sending && widget.animateSending) {
      return AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159,
            child: Transform.scale(scale: _pulseAnimation.value, child: icon),
          );
        },
      );
    }

    // Add subtle scale animation for other statuses
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 200),
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.padding,
      child: _messageStatus == MessageStatus.failed
          ? _buildFailedState()
          : _buildNormalState(),
    );
  }

  Widget _buildNormalState() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusIcon(),
        if (widget.showReadCount &&
            _messageStatus == MessageStatus.read &&
            widget.readCount > 0) ...[
          const SizedBox(width: 4),
          _buildReadCount(),
        ],
      ],
    );
  }

  Widget _buildFailedState() {
    return GestureDetector(
      onTap: widget.onRetry,
      child: Tooltip(
        message: 'Message failed to send. Tap to retry.',
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: widget.size, color: Colors.red),
              const SizedBox(width: 4),
              Text(
                'Retry',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadCount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        widget.readCount.toString(),
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: widget.size * 0.6,
        ),
      ),
    );
  }
}

/// Compact version without read count
class CompactMessageStatusIndicator extends StatelessWidget {
  final String status;
  final double size;
  final VoidCallback? onRetry;

  const CompactMessageStatusIndicator({
    super.key,
    required this.status,
    this.size = 14,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MessageStatusIndicator(
      status: status,
      size: size,
      showReadCount: false,
      onRetry: onRetry,
    );
  }
}

/// Detailed version with read count and user avatars
class DetailedMessageStatusIndicator extends StatefulWidget {
  final String status;
  final List<String> readByUsers;
  final List<String> readByAvatars;
  final double size;
  final VoidCallback? onRetry;
  final VoidCallback? onViewReadBy;

  const DetailedMessageStatusIndicator({
    super.key,
    required this.status,
    this.readByUsers = const [],
    this.readByAvatars = const [],
    this.size = 16,
    this.onRetry,
    this.onViewReadBy,
  });

  @override
  State<DetailedMessageStatusIndicator> createState() =>
      _DetailedMessageStatusIndicatorState();
}

class _DetailedMessageStatusIndicatorState
    extends State<DetailedMessageStatusIndicator> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MessageStatusIndicator(
          status: widget.status,
          readCount: widget.readByUsers.length,
          size: widget.size,
          onRetry: widget.onRetry,
        ),
        if (widget.status == 'read' && widget.readByAvatars.isNotEmpty) ...[
          const SizedBox(width: 8),
          _buildReadByAvatars(),
        ],
      ],
    );
  }

  Widget _buildReadByAvatars() {
    final visibleAvatars = widget.readByAvatars.take(3).toList();
    final remainingCount = widget.readByAvatars.length - 3;

    return GestureDetector(
      onTap: widget.onViewReadBy,
      child: SizedBox(
        height: widget.size + 4,
        width: _calculateAvatarStackWidth(
          visibleAvatars.length,
          remainingCount > 0,
        ),
        child: Stack(
          children: [
            // Stack avatars
            ...visibleAvatars.asMap().entries.map((entry) {
              final index = entry.key;
              final avatarUrl = entry.value;
              final leftOffset = index * (widget.size * 0.7);

              return Positioned(
                left: leftOffset,
                child: Container(
                  width: widget.size + 4,
                  height: widget.size + 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: widget.size / 2,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    backgroundColor: AppColors.surfaceVariant,
                    child: avatarUrl.isEmpty
                        ? Icon(
                            Icons.person,
                            size: widget.size * 0.6,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                ),
              );
            }),

            // "+X more" indicator
            if (remainingCount > 0)
              Positioned(
                left: visibleAvatars.length * (widget.size * 0.7),
                child: Container(
                  width: widget.size + 4,
                  height: widget.size + 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '+$remainingCount',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: widget.size * 0.4,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _calculateAvatarStackWidth(int visibleCount, bool hasMore) {
    double width = widget.size + 4; // First avatar
    width += (visibleCount - 1) * (widget.size * 0.7); // Overlapping avatars
    if (hasMore) {
      width += widget.size * 0.7; // More indicator
    }
    return width;
  }
}

/// Status indicator with tooltip showing detailed information
class TooltipMessageStatusIndicator extends StatelessWidget {
  final String status;
  final int readCount;
  final List<String> readByUsers;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final double size;
  final VoidCallback? onRetry;

  const TooltipMessageStatusIndicator({
    super.key,
    required this.status,
    this.readCount = 0,
    this.readByUsers = const [],
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.size = 16,
    this.onRetry,
  });

  String _buildTooltipText() {
    switch (status) {
      case 'sending':
        return 'Sending message...';
      case 'sent':
        return sentAt != null
            ? 'Sent at ${_formatTime(sentAt!)}'
            : 'Message sent';
      case 'delivered':
        return deliveredAt != null
            ? 'Delivered at ${_formatTime(deliveredAt!)}'
            : 'Message delivered';
      case 'read':
        String text = readAt != null
            ? 'Read at ${_formatTime(readAt!)}'
            : 'Message read';
        if (readByUsers.isNotEmpty) {
          text += '\nRead by: ${readByUsers.join(', ')}';
        }
        return text;
      case 'failed':
        return 'Failed to send. Tap to retry.';
      default:
        return 'Message status unknown';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _buildTooltipText(),
      child: MessageStatusIndicator(
        status: status,
        readCount: readCount,
        size: size,
        onRetry: onRetry,
      ),
    );
  }
}

/// Animated status indicator that shows transitions between states
class AnimatedMessageStatusIndicator extends StatefulWidget {
  final String status;
  final int readCount;
  final double size;
  final Duration transitionDuration;
  final VoidCallback? onRetry;

  const AnimatedMessageStatusIndicator({
    super.key,
    required this.status,
    this.readCount = 0,
    this.size = 16,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.onRetry,
  });

  @override
  State<AnimatedMessageStatusIndicator> createState() =>
      _AnimatedMessageStatusIndicatorState();
}

class _AnimatedMessageStatusIndicatorState
    extends State<AnimatedMessageStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.transitionDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedMessageStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animate when status changes
    if (widget.status != oldWidget.status) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: MessageStatusIndicator(
            status: widget.status,
            readCount: widget.readCount,
            size: widget.size,
            onRetry: widget.onRetry,
          ),
        );
      },
    );
  }
}
