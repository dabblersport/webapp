import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/widgets/custom_avatar.dart';
import '../../../../../themes/app_colors.dart';
import '../../../../../themes/app_text_styles.dart';
import '../../../../../utils/formatters/time_formatter.dart';
import 'package:dabbler/core/widgets/shimmer_loading.dart';
import 'package:dabbler/data/models/authentication/user_model.dart';

/// A reusable tile widget for displaying friend information
/// with online status, activity, and quick actions
class FriendTile extends ConsumerStatefulWidget {
  final UserModel friend;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;
  final VoidCallback? onVideoCall;
  final VoidCallback? onRemove;
  final VoidCallback? onViewProfile;
  final bool showMutualFriends;
  final bool showLastSeen;
  final bool showCurrentActivity;
  final bool enableSwipeActions;
  final bool showQuickActions;
  final EdgeInsetsGeometry? padding;
  final Widget? trailing;

  const FriendTile({
    super.key,
    required this.friend,
    this.onTap,
    this.onMessage,
    this.onVideoCall,
    this.onRemove,
    this.onViewProfile,
    this.showMutualFriends = true,
    this.showLastSeen = true,
    this.showCurrentActivity = true,
    this.enableSwipeActions = true,
    this.showQuickActions = true,
    this.padding,
    this.trailing,
  });

  @override
  ConsumerState<FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends ConsumerState<FriendTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  Widget _buildSwipeActions(Widget child) {
    if (!widget.enableSwipeActions) return child;

    return Dismissible(
      key: Key('friend_${widget.friend.id}'),
      background: _buildSwipeBackground(isLeft: true),
      secondaryBackground: _buildSwipeBackground(isLeft: false),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right - message
          widget.onMessage?.call();
        } else {
          // Swipe left - remove
          return await _showRemoveConfirmation();
        }
        return false;
      },
      child: child,
    );
  }

  Widget _buildSwipeBackground({required bool isLeft}) {
    return Container(
      color: isLeft ? Colors.blue.shade100 : Colors.red.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: isLeft
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            Icon(
              isLeft ? Icons.message : Icons.delete,
              color: isLeft ? Colors.blue : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              isLeft ? 'Message' : 'Remove',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isLeft ? Colors.blue : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showRemoveConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
          'Are you sure you want to remove ${widget.friend.displayName} from your friends?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              widget.onRemove?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: _buildSwipeActions(
            Container(
              margin:
                  widget.padding ??
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: _isPressed
                      ? AppColors.primary.withOpacity(0.2)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.onTap ?? widget.onViewProfile,
                  onTapDown: _onTapDown,
                  onTapUp: _onTapUp,
                  onTapCancel: _onTapCancel,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildAvatar(),
                            const SizedBox(width: 12),
                            Expanded(child: _buildUserInfo()),
                            if (widget.trailing != null) ...[
                              const SizedBox(width: 8),
                              widget.trailing!,
                            ] else if (widget.showQuickActions)
                              _buildQuickActions(),
                          ],
                        ),
                        if (widget.showMutualFriends) ...[
                          const SizedBox(height: 12),
                          _buildMutualFriends(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        Hero(
          tag: 'friend_avatar_${widget.friend.id}',
          child: CustomAvatar(
            imageUrl: widget.friend.profileImageUrl,
            radius: 28,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.green, // Default to online for now
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.friend.displayName,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          widget.friend.email ?? '@unknown',
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (widget.showLastSeen) ...[
          const SizedBox(height: 4),
          _buildLastSeenInfo(),
        ],
        if (widget.showCurrentActivity) ...[
          const SizedBox(height: 4),
          _buildCurrentActivity(),
        ],
      ],
    );
  }

  Widget _buildLastSeenInfo() {
    // Mock online status check
    final isOnline = DateTime.now().millisecond % 2 == 0;
    if (isOnline) {
      return Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Online now',
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Text(
      'Last seen ${TimeFormatter.format(DateTime.now().subtract(const Duration(hours: 2)))}',
      style: AppTextStyles.bodySmall.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildCurrentActivity() {
    // Mock activity data
    final mockActivity = {
      'type': 'football',
      'description': 'Playing Football',
      'location': 'Central Park',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getActivityIcon(mockActivity['type']),
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              mockActivity['description'] ?? 'Active',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'playing':
        return Icons.sports_basketball;
      case 'watching':
        return Icons.visibility;
      case 'listening':
        return Icons.headphones;
      case 'training':
        return Icons.fitness_center;
      default:
        return Icons.circle;
    }
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: Icons.message_outlined,
          onTap: widget.onMessage,
          tooltip: 'Message',
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.videocam_outlined,
          onTap: widget.onVideoCall,
          tooltip: 'Video Call',
        ),
        const SizedBox(width: 8),
        _buildMoreActionsButton(),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreActionsButton() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 12),
              const Text('View Profile'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'block',
          child: Row(
            children: [
              const Icon(Icons.block, color: Colors.orange),
              const SizedBox(width: 12),
              Text('Block User', style: TextStyle(color: Colors.orange)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              const Icon(Icons.person_remove, color: Colors.red),
              const SizedBox(width: 12),
              Text('Remove Friend', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'profile':
            widget.onViewProfile?.call();
            break;
          case 'block':
            _showBlockConfirmation();
            break;
          case 'remove':
            _showRemoveConfirmation().then((confirmed) {
              if (confirmed) {
                widget.onRemove?.call();
              }
            });
            break;
        }
      },
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
          'Are you sure you want to block ${widget.friend.displayName}? They will be removed from your friends list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Handle block user
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  Widget _buildMutualFriends() {
    return FutureBuilder<List<UserModel>>(
      future: _getMutualFriends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ShimmerLoading(
            height: 24,
            width: double.infinity,
            borderRadius: BorderRadius.circular(12),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        return Text(
          '${snapshot.data?.length ?? 0} mutual friends',
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }

  Future<List<UserModel>> _getMutualFriends() async {
    // In real implementation, fetch mutual friends from repository
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock data
    return [
      UserModel(
        id: '1',
        fullName: 'John Doe',
        email: 'john@example.com',
        avatarUrl: 'https://example.com/avatar1.jpg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      UserModel(
        id: '2',
        fullName: 'Jane Smith',
        email: 'jane@example.com',
        avatarUrl: 'https://example.com/avatar2.jpg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }
}

/// Compact version of FriendTile for lists
class CompactFriendTile extends StatelessWidget {
  final UserModel friend;
  final VoidCallback? onTap;
  final Widget? trailing;

  const CompactFriendTile({
    super.key,
    required this.friend,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return FriendTile(
      friend: friend,
      onTap: onTap,
      trailing: trailing,
      showMutualFriends: false,
      showCurrentActivity: false,
      showQuickActions: false,
      enableSwipeActions: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
