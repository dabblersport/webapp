import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dabbler/data/models/rewards/achievement.dart';

enum BadgeRarity { common, uncommon, rare, epic, legendary, mythic }

enum BadgeQualitySettings { low, medium, high, ultra }

class BadgeDisplay extends StatefulWidget {
  final Achievement achievement;
  final double size;
  final BadgeRarity rarity;
  final BadgeQualitySettings quality;
  final bool enableInteractions;
  final bool enableParticleEffects;
  final bool enableShineAnimation;
  final bool enableRotationOnDrag;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  const BadgeDisplay({
    super.key,
    required this.achievement,
    this.size = 120,
    this.rarity = BadgeRarity.common,
    this.quality = BadgeQualitySettings.high,
    this.enableInteractions = true,
    this.enableParticleEffects = true,
    this.enableShineAnimation = true,
    this.enableRotationOnDrag = true,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
  });

  @override
  State<BadgeDisplay> createState() => _BadgeDisplayState();
}

class _BadgeDisplayState extends State<BadgeDisplay>
    with TickerProviderStateMixin {
  late AnimationController _shineController;
  late AnimationController _rotationController;
  late AnimationController _flipController;
  late AnimationController _scaleController;
  late AnimationController _particleController;

  late Animation<double> _shineAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _flipAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _particleAnimation;

  double _currentRotationX = 0.0;
  double _currentRotationY = 0.0;
  bool _isFlipped = false;
  bool _isDragging = false;

  final List<RarityParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeParticles();
    _startShineAnimation();
  }

  void _initializeAnimations() {
    _shineController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _shineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.elasticOut),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeOut),
    );

    if (widget.enableParticleEffects) {
      _particleController.repeat();
    }
  }

  void _initializeParticles() {
    if (!widget.enableParticleEffects) return;

    final particleCount = _getParticleCount();
    final random = math.Random();

    for (int i = 0; i < particleCount; i++) {
      _particles.add(
        RarityParticle(
          position: Offset(
            random.nextDouble() * widget.size,
            random.nextDouble() * widget.size,
          ),
          velocity: Offset(
            (random.nextDouble() - 0.5) * 2,
            (random.nextDouble() - 0.5) * 2,
          ),
          color: _getRarityParticleColor(),
          size: random.nextDouble() * 3 + 1,
          life: random.nextDouble() * 2 + 1,
          opacity: random.nextDouble() * 0.8 + 0.2,
        ),
      );
    }
  }

  void _startShineAnimation() {
    if (widget.enableShineAnimation) {
      _shineController.repeat();
    }
  }

  @override
  void dispose() {
    _shineController.dispose();
    _rotationController.dispose();
    _flipController.dispose();
    _scaleController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      onLongPress: _onLongPress,
      onDoubleTap: _onDoubleTap,
      onPanStart: widget.enableRotationOnDrag ? _onPanStart : null,
      onPanUpdate: widget.enableRotationOnDrag ? _onPanUpdate : null,
      onPanEnd: widget.enableRotationOnDrag ? _onPanEnd : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _scaleAnimation,
          _rotationAnimation,
          _flipAnimation,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background shadow
                  if (widget.quality != BadgeQualitySettings.low)
                    _buildShadow(),

                  // Particle effects
                  if (widget.enableParticleEffects) _buildParticleEffects(),

                  // Main badge
                  _buildMainBadge(),

                  // Shine effect overlay
                  if (widget.enableShineAnimation &&
                      widget.quality != BadgeQualitySettings.low)
                    _buildShineEffect(),

                  // Rarity border effect
                  if (widget.rarity != BadgeRarity.common) _buildRarityBorder(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShadow() {
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(2, 4 + (_currentRotationX * 0.1)),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: widget.quality == BadgeQualitySettings.ultra
                    ? 15
                    : 10,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainBadge() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(_currentRotationX * 0.01)
        ..rotateY(_currentRotationY * 0.01),
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final isShowingBack = _flipAnimation.value > 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateY(_flipAnimation.value * math.pi),
            child: isShowingBack ? _buildBadgeBack() : _buildBadgeFront(),
          );
        },
      ),
    );
  }

  Widget _buildBadgeFront() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _getTierGradient(),
        border: Border.all(
          color: _getTierBorderColor(),
          width: widget.quality == BadgeQualitySettings.ultra ? 4 : 3,
        ),
        boxShadow: widget.quality != BadgeQualitySettings.low
            ? [
                BoxShadow(
                  color: _getTierColor().withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base material effect
          _buildMaterialEffect(),

          // Achievement icon
          _buildAchievementIcon(),

          // Tier indicator
          Positioned(bottom: widget.size * 0.1, child: _buildTierBadge()),
        ],
      ),
    );
  }

  Widget _buildBadgeBack() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[300]!, Colors.grey[400]!, Colors.grey[500]!],
        ),
        border: Border.all(color: Colors.grey[600]!, width: 3),
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.size * 0.15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.achievement.name,
              style: TextStyle(
                fontSize: widget.size * 0.1,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: widget.size * 0.02),
            Text(
              '${widget.achievement.points} pts',
              style: TextStyle(
                fontSize: widget.size * 0.08,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialEffect() {
    return Container(
      width: widget.size * 0.9,
      height: widget.size * 0.9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 0.8,
          colors: _getMaterialEffectColors(),
        ),
      ),
    );
  }

  Widget _buildAchievementIcon() {
    return Container(
      width: widget.size * 0.5,
      height: widget.size * 0.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.9),
        boxShadow: widget.quality != BadgeQualitySettings.low
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Icon(
        _getCategoryIcon(),
        size: widget.size * 0.25,
        color: _getTierColor(),
      ),
    );
  }

  Widget _buildTierBadge() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.size * 0.08,
        vertical: widget.size * 0.02,
      ),
      decoration: BoxDecoration(
        color: _getTierColor(),
        borderRadius: BorderRadius.circular(widget.size * 0.02),
        boxShadow: widget.quality != BadgeQualitySettings.low
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        widget.achievement.tier.toString().split('.').last.toUpperCase(),
        style: TextStyle(
          fontSize: widget.size * 0.06,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildShineEffect() {
    return AnimatedBuilder(
      animation: _shineAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              center: Alignment.center,
              startAngle: _shineAnimation.value * 2 * math.pi,
              endAngle: _shineAnimation.value * 2 * math.pi + math.pi * 0.5,
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(0.4),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRarityBorder() {
    return Container(
      width: widget.size + 8,
      height: widget.size + 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _getRarityColor(), width: 3),
        boxShadow: [
          BoxShadow(
            color: _getRarityColor().withOpacity(0.6),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildParticleEffects() {
    return AnimatedBuilder(
      animation: _particleAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: RarityParticlePainter(
            particles: _particles,
            animation: _particleAnimation.value,
            rarity: widget.rarity,
          ),
        );
      },
    );
  }

  void _onTap() {
    if (!widget.enableInteractions) return;

    HapticFeedback.lightImpact();
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });

    widget.onTap?.call();
  }

  void _onLongPress() {
    if (!widget.enableInteractions) return;

    HapticFeedback.heavyImpact();
    _startShowcaseAnimation();
    widget.onLongPress?.call();
  }

  void _onDoubleTap() {
    if (!widget.enableInteractions) return;

    HapticFeedback.mediumImpact();
    _flipBadge();
    widget.onDoubleTap?.call();
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    setState(() {
      _currentRotationY += details.delta.dx * 0.01;
      _currentRotationX -= details.delta.dy * 0.01;

      // Clamp rotation values
      _currentRotationX = _currentRotationX.clamp(-0.3, 0.3);
      _currentRotationY = _currentRotationY.clamp(-0.3, 0.3);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    _returnToCenter();
  }

  void _returnToCenter() {
    _rotationController.reset();
    _rotationController.forward();

    _rotationController.addListener(() {
      setState(() {
        _currentRotationX = _currentRotationX * (1 - _rotationAnimation.value);
        _currentRotationY = _currentRotationY * (1 - _rotationAnimation.value);
      });
    });
  }

  void _flipBadge() {
    _isFlipped = !_isFlipped;
    if (_isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  void _startShowcaseAnimation() {
    // Enhanced showcase animation
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });

    if (widget.enableShineAnimation) {
      _shineController.reset();
      _shineController.forward();
    }
  }

  Color _getTierColor() {
    return Color(
      int.parse('0xFF${widget.achievement.getTierColorHex().substring(1)}'),
    );
  }

  Color _getTierBorderColor() {
    final baseColor = _getTierColor();
    return Color.lerp(baseColor, Colors.black, 0.3)!;
  }

  LinearGradient _getTierGradient() {
    final baseColor = _getTierColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        baseColor.withOpacity(0.8),
        baseColor,
        Color.lerp(baseColor, Colors.black, 0.2)!,
      ],
    );
  }

  List<Color> _getMaterialEffectColors() {
    final baseColor = _getTierColor();
    return [
      Colors.white.withOpacity(0.6),
      baseColor.withOpacity(0.3),
      baseColor.withOpacity(0.1),
    ];
  }

  Color _getRarityColor() {
    switch (widget.rarity) {
      case BadgeRarity.common:
        return Colors.grey;
      case BadgeRarity.uncommon:
        return Colors.green;
      case BadgeRarity.rare:
        return Colors.blue;
      case BadgeRarity.epic:
        return Colors.purple;
      case BadgeRarity.legendary:
        return Colors.orange;
      case BadgeRarity.mythic:
        return Colors.red;
    }
  }

  Color _getRarityParticleColor() {
    final rarityColor = _getRarityColor();
    return Color.lerp(rarityColor, Colors.white, 0.3)!;
  }

  int _getParticleCount() {
    switch (widget.rarity) {
      case BadgeRarity.common:
        return 0;
      case BadgeRarity.uncommon:
        return 3;
      case BadgeRarity.rare:
        return 6;
      case BadgeRarity.epic:
        return 12;
      case BadgeRarity.legendary:
        return 20;
      case BadgeRarity.mythic:
        return 30;
    }
  }

  IconData _getCategoryIcon() {
    switch (widget.achievement.category) {
      case AchievementCategory.gameParticipation:
        return Icons.sports_esports;
      case AchievementCategory.social:
        return Icons.people;
      case AchievementCategory.skillPerformance:
        return Icons.trending_up;
      case AchievementCategory.milestone:
        return Icons.flag;
      case AchievementCategory.special:
        return Icons.star;
      default:
        // Fallback icon for any future/unknown categories (e.g., legacy 'gaming')
        return Icons.sports_esports;
    }
  }
}

class RarityParticle {
  final Offset position;
  final Offset velocity;
  final Color color;
  final double size;
  final double life;
  final double opacity;

  const RarityParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.life,
    required this.opacity,
  });
}

class RarityParticlePainter extends CustomPainter {
  final List<RarityParticle> particles;
  final double animation;
  final BadgeRarity rarity;

  RarityParticlePainter({
    required this.particles,
    required this.animation,
    required this.rarity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rarity == BadgeRarity.common) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      final progress = animation % 1.0;
      final currentPosition = Offset(
        particle.position.dx + particle.velocity.dx * progress * 100,
        particle.position.dy + particle.velocity.dy * progress * 100,
      );

      // Keep particles within bounds
      if (currentPosition.dx < 0 ||
          currentPosition.dx > size.width ||
          currentPosition.dy < 0 ||
          currentPosition.dy > size.height) {
        continue;
      }

      final alpha = (particle.opacity * (1 - progress)).clamp(0.0, 1.0);
      paint.color = particle.color.withOpacity(alpha);

      // Draw different particle shapes based on rarity
      switch (rarity) {
        case BadgeRarity.uncommon:
        case BadgeRarity.rare:
          canvas.drawCircle(currentPosition, particle.size, paint);
          break;
        case BadgeRarity.epic:
          _drawStar(canvas, currentPosition, particle.size, paint);
          break;
        case BadgeRarity.legendary:
          _drawDiamond(canvas, currentPosition, particle.size, paint);
          break;
        case BadgeRarity.mythic:
          _drawFlame(canvas, currentPosition, particle.size, paint);
          break;
        case BadgeRarity.common:
          break;
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final double outerRadius = size;
    final double innerRadius = size * 0.4;

    for (int i = 0; i < 10; i++) {
      final double angle = (i * math.pi) / 5;
      final double radius = i.isEven ? outerRadius : innerRadius;
      final double x = center.dx + radius * math.cos(angle);
      final double y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawFlame(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size);
    path.quadraticBezierTo(
      center.dx - size,
      center.dy,
      center.dx,
      center.dy - size,
    );
    path.quadraticBezierTo(
      center.dx + size,
      center.dy,
      center.dx,
      center.dy + size,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(RarityParticlePainter oldDelegate) {
    return animation != oldDelegate.animation;
  }
}
