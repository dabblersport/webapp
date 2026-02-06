import 'package:flutter/material.dart';

/// A reusable typing indicator widget showing animated dots
/// and user names who are currently typing
class TypingIndicator extends StatefulWidget {
  final List<String> userNames;
  final bool isCompact;
  final Color? dotColor;
  final Color? textColor;
  final Duration animationDuration;
  final Duration hideTimeout;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTimeout;

  const TypingIndicator({
    super.key,
    required this.userNames,
    this.isCompact = false,
    this.dotColor,
    this.textColor,
    this.animationDuration = const Duration(milliseconds: 600),
    this.hideTimeout = const Duration(seconds: 3),
    this.padding,
    this.onTimeout,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startHideTimer();
  }

  @override
  void didUpdateWidget(TypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Restart hide timer when userNames change
    if (oldWidget.userNames != widget.userNames) {
      _startHideTimer();

      // Fade in if new users started typing
      if (widget.userNames.isNotEmpty && oldWidget.userNames.isEmpty) {
        _fadeController.forward();
      }
    }
  }

  void _setupAnimations() {
    // Main dots animation controller
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Fade in/out controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Create staggered animations for each dot
    _dotAnimations = List.generate(3, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.2,
            (index * 0.2) + 0.4,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    // Start animations if users are typing
    if (widget.userNames.isNotEmpty) {
      _fadeController.forward();
      _animationController.repeat();
    }
  }

  void _startHideTimer() {
    // Cancel existing timer and start new one
    Future.delayed(widget.hideTimeout, () {
      if (mounted && widget.userNames.isNotEmpty) {
        _fadeController.reverse().then((_) {
          widget.onTimeout?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String _getTypingText() {
    if (widget.userNames.isEmpty) return '';

    if (widget.isCompact) {
      return widget.userNames.length == 1
          ? '${widget.userNames.first} is typing...'
          : '${widget.userNames.length} people are typing...';
    }

    if (widget.userNames.length == 1) {
      return '${widget.userNames.first} is typing';
    } else if (widget.userNames.length == 2) {
      return '${widget.userNames[0]} and ${widget.userNames[1]} are typing';
    } else if (widget.userNames.length == 3) {
      return '${widget.userNames[0]}, ${widget.userNames[1]} and ${widget.userNames[2]} are typing';
    } else {
      return '${widget.userNames[0]}, ${widget.userNames[1]} and ${widget.userNames.length - 2} others are typing';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userNames.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding:
            widget.padding ??
            (widget.isCompact
                ? const EdgeInsets.symmetric(vertical: 2)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
        child: widget.isCompact ? _buildCompactView() : _buildFullView(),
      ),
    );
  }

  Widget _buildCompactView() {
    return Row(
      children: [
        _buildAnimatedDots(size: 4),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _getTypingText(),
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      widget.textColor ??
                      Theme.of(context).colorScheme.onSurface,
                  fontStyle: FontStyle.italic,
                ) ??
                TextStyle(
                  color:
                      widget.textColor ??
                      Theme.of(context).colorScheme.onSurface,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFullView() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(child: _buildAnimatedDots(size: 6)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getTypingText(),
                style:
                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          widget.textColor ??
                          Theme.of(context).colorScheme.onSurface,
                      fontStyle: FontStyle.italic,
                    ) ??
                    TextStyle(
                      color:
                          widget.textColor ??
                          Theme.of(context).colorScheme.onSurface,
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
              ),
              if (widget.userNames.length > 1) ...[
                const SizedBox(height: 2),
                Text(
                  _buildUsersList(),
                  style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 11,
                      ) ??
                      TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedDots({required double size}) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _dotAnimations[index],
              builder: (context, child) {
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: size * 0.3),
                  child: Transform.translate(
                    offset: Offset(0, -size * _dotAnimations[index].value),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color:
                            (widget.dotColor ??
                                    Theme.of(context).colorScheme.primary)
                                .withValues(
                                  alpha:
                                      0.4 + (0.6 * _dotAnimations[index].value),
                                ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        );
      },
    );
  }

  String _buildUsersList() {
    if (widget.userNames.length <= 3) {
      return widget.userNames.join(', ');
    }
    return '${widget.userNames.take(3).join(', ')} and ${widget.userNames.length - 3} others';
  }
}

/// Bubble version for chat messages
class TypingBubble extends StatefulWidget {
  final List<String> userNames;
  final String? avatarUrl;
  final String? displayName;
  final VoidCallback? onTimeout;

  const TypingBubble({
    super.key,
    required this.userNames,
    this.avatarUrl,
    this.displayName,
    this.onTimeout,
  });

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Auto-hide after timeout
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onTimeout?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.avatarUrl != null) ...[
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: widget.avatarUrl!.isNotEmpty
                          ? NetworkImage(widget.avatarUrl!)
                          : null,
                      child: widget.avatarUrl!.isEmpty
                          ? Text(
                              widget.displayName
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  '?',
                              style:
                                  Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.bold) ??
                                  const TextStyle(fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.6,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TypingIndicator(
                      userNames: widget.userNames,
                      isCompact: true,
                      dotColor: Theme.of(context).colorScheme.primary,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Simple dots-only indicator for minimal spaces
class TypingDots extends StatefulWidget {
  final Color? color;
  final double size;
  final Duration duration;

  const TypingDots({
    super.key,
    this.color,
    this.size = 4,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _animations = List.generate(3, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.2,
            (index * 0.2) + 0.4,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.size * 0.3),
              child: Transform.translate(
                offset: Offset(0, -widget.size * _animations[index].value),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color:
                        (widget.color ?? Theme.of(context).colorScheme.primary)
                            .withValues(
                              alpha: 0.4 + (0.6 * _animations[index].value),
                            ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Provider-based typing indicator that manages state
class ManagedTypingIndicator extends StatefulWidget {
  final String conversationId;
  final bool isCompact;
  final VoidCallback? onUsersTyping;
  final VoidCallback? onUsersStoppedTyping;

  const ManagedTypingIndicator({
    super.key,
    required this.conversationId,
    this.isCompact = false,
    this.onUsersTyping,
    this.onUsersStoppedTyping,
  });

  @override
  State<ManagedTypingIndicator> createState() => _ManagedTypingIndicatorState();
}

class _ManagedTypingIndicatorState extends State<ManagedTypingIndicator> {
  List<String> _typingUsers = [];

  @override
  void initState() {
    super.initState();
    // In real implementation, listen to typing events from chat provider
    _subscribeToTypingEvents();
  }

  void _subscribeToTypingEvents() {
    // Mock typing events - in real app, this would come from WebSocket/Provider
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _typingUsers = ['John Doe', 'Jane Smith'];
        });
        widget.onUsersTyping?.call();

        // Auto-stop typing after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _typingUsers = [];
            });
            widget.onUsersStoppedTyping?.call();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return TypingIndicator(
      userNames: _typingUsers,
      isCompact: widget.isCompact,
      onTimeout: () {
        setState(() {
          _typingUsers = [];
        });
        widget.onUsersStoppedTyping?.call();
      },
    );
  }
}
