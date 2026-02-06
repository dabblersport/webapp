import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:dabbler/data/models/rewards/leaderboard_entry.dart';

class PodiumWidget extends StatefulWidget {
  final List<LeaderboardEntry> entries;
  final AnimationController animationController;
  final Function(LeaderboardEntry)? onEntryTapped;
  final bool showConfetti;
  final bool showCrowns;

  const PodiumWidget({
    super.key,
    required this.entries,
    required this.animationController,
    this.onEntryTapped,
    this.showConfetti = true,
    this.showCrowns = true,
  });

  @override
  State<PodiumWidget> createState() => _PodiumWidgetState();
}

class _PodiumWidgetState extends State<PodiumWidget>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _crownController;
  late List<AnimationController> _podiumControllers;

  // Podium animations
  late List<Animation<double>> _podiumScaleAnimations;
  late List<Animation<double>> _podiumSlideAnimations;
  late List<Animation<double>> _podiumBounceAnimations;

  // Confetti animations
  late Animation<double> _confettiAnimation;
  late List<Offset> _confettiPositions;
  late List<Color> _confettiColors;

  // Crown animations
  late Animation<double> _crownBounceAnimation;
  late Animation<double> _crownRotateAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    // Confetti controller
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // Crown controller
    _crownController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Podium controllers (one for each podium position)
    _podiumControllers = List.generate(
      3,
      (index) => AnimationController(
        duration: Duration(milliseconds: 800 + index * 200),
        vsync: this,
      ),
    );

    // Podium animations
    _podiumScaleAnimations = _podiumControllers
        .map(
          (controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.elasticOut),
          ),
        )
        .toList();

    _podiumSlideAnimations = _podiumControllers
        .map(
          (controller) => Tween<double>(
            begin: 100.0,
            end: 0.0,
          ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut)),
        )
        .toList();

    _podiumBounceAnimations = _podiumControllers
        .map(
          (controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.bounceOut),
          ),
        )
        .toList();

    // Confetti animation
    _confettiAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _confettiController, curve: Curves.easeOut),
    );

    // Crown animations
    _crownBounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _crownController, curve: Curves.elasticOut),
    );

    _crownRotateAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _crownController, curve: Curves.easeInOut),
    );

    // Initialize confetti particles
    _initializeConfetti();
  }

  void _initializeConfetti() {
    final random = math.Random();
    _confettiPositions = List.generate(20, (index) {
      return Offset(random.nextDouble() * 300, random.nextDouble() * 100);
    });

    _confettiColors = [
      Colors.yellow,
      Colors.orange,
      Colors.pink,
      Colors.purple,
      Colors.blue,
      Colors.green,
    ];
  }

  void _startAnimationSequence() {
    // Start podium animations with staggered delay
    for (
      int i = 0;
      i < _podiumControllers.length && i < widget.entries.length;
      i++
    ) {
      Future.delayed(Duration(milliseconds: i * 300), () {
        if (mounted) {
          _podiumControllers[i].forward();
        }
      });
    }

    // Start crown animation after podiums
    if (widget.showCrowns && widget.entries.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          _crownController.repeat(reverse: true);
        }
      });
    }

    // Start confetti after all animations
    if (widget.showConfetti && widget.entries.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _confettiController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _crownController.dispose();
    for (final controller in _podiumControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return _buildEmptyPodium();
    }

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          // Background gradient
          _buildBackground(),
          // Confetti layer
          if (widget.showConfetti) _buildConfetti(),
          // Podium structure
          _buildPodiumStructure(),
          // Winner entries
          _buildWinnerCards(),
          // Crown decorations
          if (widget.showCrowns) _buildCrowns(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.amber.withOpacity(0.1),
            Colors.orange.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildEmptyPodium() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No winners yet!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Be the first to claim the podium',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfetti() {
    return AnimatedBuilder(
      animation: _confettiAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, 280),
          painter: ConfettiPainter(
            animation: _confettiAnimation.value,
            particles: _confettiPositions,
            colors: _confettiColors,
          ),
        );
      },
    );
  }

  Widget _buildPodiumStructure() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Second place podium
          if (widget.entries.length >= 2)
            _buildPodiumBase(1, 80, const Color(0xFFC0C0C0)),

          // First place podium (center)
          if (widget.entries.isNotEmpty) _buildPodiumBase(0, 120, Colors.amber),

          // Third place podium
          if (widget.entries.length >= 3)
            _buildPodiumBase(2, 60, const Color(0xFFCD7F32)),
        ],
      ),
    );
  }

  Widget _buildPodiumBase(int position, double height, Color color) {
    final animationIndex = position;

    return AnimatedBuilder(
      animation: _podiumControllers[animationIndex],
      builder: (context, child) {
        return Transform.scale(
          scale: _podiumScaleAnimations[animationIndex].value,
          child: Transform.translate(
            offset: Offset(0, _podiumSlideAnimations[animationIndex].value),
            child: Container(
              width: 80,
              height: height * _podiumBounceAnimations[animationIndex].value,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${position + 1}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          offset: const Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _getPositionText(position),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
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

  Widget _buildWinnerCards() {
    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Second place
          if (widget.entries.length >= 2)
            _buildWinnerCard(1, widget.entries[1]),

          const SizedBox(width: 8),

          // First place (center, higher)
          if (widget.entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildWinnerCard(0, widget.entries[0]),
            ),

          const SizedBox(width: 8),

          // Third place
          if (widget.entries.length >= 3)
            _buildWinnerCard(2, widget.entries[2]),
        ],
      ),
    );
  }

  Widget _buildWinnerCard(int position, LeaderboardEntry entry) {
    final animationIndex = position;

    return AnimatedBuilder(
      animation: _podiumControllers[animationIndex],
      builder: (context, child) {
        return Transform.scale(
          scale: _podiumScaleAnimations[animationIndex].value,
          child: Transform.translate(
            offset: Offset(0, _podiumSlideAnimations[animationIndex].value),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onEntryTapped?.call(entry);
              },
              child: Container(
                width: 80,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getPositionColor(position),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getPositionColor(position).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User avatar
                    Hero(
                      tag: 'podium_avatar_${entry.userId}',
                      child: CircleAvatar(
                        radius: position == 0 ? 28 : 24,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: entry.avatarUrl != null
                            ? NetworkImage(entry.avatarUrl!)
                            : null,
                        child: entry.avatarUrl == null
                            ? Icon(
                                Icons.person,
                                size: position == 0 ? 28 : 24,
                                color: Colors.grey[600],
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Username
                    Text(
                      entry.username,
                      style: TextStyle(
                        fontSize: position == 0 ? 12 : 10,
                        fontWeight: FontWeight.bold,
                        color: _getPositionColor(position),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),

                    // Points
                    Text(
                      '${entry.periodPoints.toInt()}',
                      style: TextStyle(
                        fontSize: position == 0 ? 11 : 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).animate().scale(
      delay: Duration(milliseconds: 200 + position * 100),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
    );
  }

  Widget _buildCrowns() {
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Second place crown
          if (widget.entries.length >= 2) _buildCrown(1),

          const SizedBox(width: 88),

          // First place crown (center, higher)
          if (widget.entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildCrown(0),
            ),

          const SizedBox(width: 88),

          // Third place crown
          if (widget.entries.length >= 3) _buildCrown(2),
        ],
      ),
    );
  }

  Widget _buildCrown(int position) {
    return AnimatedBuilder(
          animation: _crownController,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.8 + (_crownBounceAnimation.value * 0.2),
              child: Transform.rotate(
                angle: _crownRotateAnimation.value,
                child: Icon(
                  Icons.workspace_premium,
                  size: position == 0 ? 32 : 24,
                  color: _getCrownColor(position),
                ),
              ),
            );
          },
        )
        .animate(delay: Duration(milliseconds: 1000 + position * 200))
        .scale(
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
        );
  }

  Color _getPositionColor(int position) {
    switch (position) {
      case 0:
        return const Color(0xFFFFD700); // Gold
      case 1:
        return const Color(0xFFC0C0C0); // Silver
      case 2:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }

  Color _getCrownColor(int position) {
    switch (position) {
      case 0:
        return const Color(0xFFFFD700); // Gold
      case 1:
        return const Color(0xFFC0C0C0); // Silver
      case 2:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }

  String _getPositionText(int position) {
    switch (position) {
      case 0:
        return 'FIRST';
      case 1:
        return 'SECOND';
      case 2:
        return 'THIRD';
      default:
        return '';
    }
  }
}

class ConfettiPainter extends CustomPainter {
  final double animation;
  final List<Offset> particles;
  final List<Color> colors;

  ConfettiPainter({
    required this.animation,
    required this.particles,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    // Fixed seed for consistent animation

    for (int i = 0; i < particles.length; i++) {
      final particle = particles[i];
      final color = colors[i % colors.length];

      // Animate particle position
      final progress = (animation + (i / particles.length)) % 1.0;
      final x = particle.dx + (math.sin(progress * math.pi * 4) * 20);
      final y = particle.dy + (progress * size.height * 1.5);

      // Skip if particle is out of bounds
      if (y > size.height) continue;

      paint.color = color.withOpacity(0.8 * (1 - progress));

      // Draw confetti piece (small rectangle with rotation)
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 4);
      canvas.drawRect(const Rect.fromLTWH(-3, -1, 6, 2), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return animation != oldDelegate.animation;
  }
}
