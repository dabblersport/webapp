import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dabbler/data/models/rewards/badge_tier.dart';

enum TierDisplayMode { frame, badge, progress, comparison }

enum MaterialType { bronze, silver, gold, platinum, diamond }

class BadgeTierIndicator extends StatefulWidget {
  final BadgeTier currentTier;
  final BadgeTier? nextTier;
  final double progress; // Progress to next tier (0.0 to 1.0)
  final TierDisplayMode displayMode;
  final double size;
  final bool showProgressText;
  final bool showNextTierPreview;
  final bool showTierBenefits;
  final bool enableAnimations;
  final bool enableUpgradeAnimation;
  final bool enableComparison;
  final List<String> tierBenefits;
  final VoidCallback? onTap;
  final VoidCallback? onUpgradeComplete;

  const BadgeTierIndicator({
    super.key,
    required this.currentTier,
    this.nextTier,
    this.progress = 0.0,
    this.displayMode = TierDisplayMode.frame,
    this.size = 80,
    this.showProgressText = true,
    this.showNextTierPreview = false,
    this.showTierBenefits = false,
    this.enableAnimations = true,
    this.enableUpgradeAnimation = true,
    this.enableComparison = false,
    this.tierBenefits = const [],
    this.onTap,
    this.onUpgradeComplete,
  });

  @override
  State<BadgeTierIndicator> createState() => _BadgeTierIndicatorState();
}

class _BadgeTierIndicatorState extends State<BadgeTierIndicator>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _upgradeController;
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _sparkleController;

  late Animation<double> _glowAnimation;
  late Animation<double> _upgradeAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _sparkleAnimation;

  bool _showingUpgrade = false;
  bool _showTooltip = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _upgradeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _upgradeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _upgradeController, curve: Curves.elasticOut),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: widget.progress)
        .animate(
          CurvedAnimation(
            parent: _progressController,
            curve: Curves.easeOutCubic,
          ),
        );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );

    _upgradeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onUpgradeComplete?.call();
        _showingUpgrade = false;
      }
    });
  }

  void _startAnimations() {
    if (widget.enableAnimations) {
      _glowController.repeat(reverse: true);
      _progressController.forward();

      if (widget.progress >= 1.0 && widget.enableUpgradeAnimation) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _triggerUpgradeAnimation();
        });
      }
    }
  }

  void _triggerUpgradeAnimation() {
    if (!widget.enableUpgradeAnimation || _showingUpgrade) return;

    setState(() {
      _showingUpgrade = true;
    });

    HapticFeedback.heavyImpact();
    _upgradeController.forward();
    _sparkleController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);

    // Stop sparkle and pulse after upgrade animation
    Future.delayed(const Duration(milliseconds: 1500), () {
      _sparkleController.stop();
      _pulseController.stop();
    });
  }

  @override
  void didUpdateWidget(BadgeTierIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.progress != widget.progress) {
      _progressAnimation =
          Tween<double>(
            begin: oldWidget.progress,
            end: widget.progress,
          ).animate(
            CurvedAnimation(
              parent: _progressController,
              curve: Curves.easeOutCubic,
            ),
          );
      _progressController.reset();
      _progressController.forward();

      if (widget.progress >= 1.0 && oldWidget.progress < 1.0) {
        Future.delayed(const Duration(milliseconds: 800), () {
          _triggerUpgradeAnimation();
        });
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _upgradeController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
        if (widget.showTierBenefits) {
          _toggleTooltip();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTierDisplay(),

          if (widget.showProgressText || widget.showNextTierPreview)
            const SizedBox(height: 8),

          if (widget.showProgressText) _buildProgressText(),

          if (widget.showNextTierPreview && widget.nextTier != null)
            const SizedBox(height: 4),

          if (widget.showNextTierPreview && widget.nextTier != null)
            _buildNextTierPreview(),

          if (_showTooltip && widget.showTierBenefits) _buildBenefitsTooltip(),
        ],
      ),
    );
  }

  Widget _buildTierDisplay() {
    switch (widget.displayMode) {
      case TierDisplayMode.frame:
        return _buildFrameDisplay();
      case TierDisplayMode.badge:
        return _buildBadgeDisplay();
      case TierDisplayMode.progress:
        return _buildProgressDisplay();
      case TierDisplayMode.comparison:
        return _buildComparisonDisplay();
    }
  }

  Widget _buildFrameDisplay() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _glowAnimation,
        _upgradeAnimation,
        _pulseAnimation,
      ]),
      builder: (context, child) {
        final scale = _showingUpgrade
            ? (1.0 + _upgradeAnimation.value * 0.3)
            : _pulseAnimation.value;

        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow effect
              if (widget.enableAnimations) _buildGlowEffect(),

              // Sparkle effects during upgrade
              if (_showingUpgrade) _buildSparkleEffects(),

              // Main frame
              _buildMainFrame(),

              // Tier icon
              _buildTierIcon(),

              // Upgrade explosion effect
              if (_showingUpgrade) _buildUpgradeEffect(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgeDisplay() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _getTierGradient(),
        border: Border.all(color: _getTierColor().withOpacity(0.8), width: 3),
        boxShadow: [
          BoxShadow(
            color: _getTierColor().withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getTierDisplayName().substring(0, 1),
          style: TextStyle(
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDisplay() {
    return Column(
      children: [
        _buildFrameDisplay(),
        const SizedBox(height: 12),
        _buildProgressBar(),
      ],
    );
  }

  Widget _buildComparisonDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Current tier
        Column(
          children: [
            _buildMiniFrame(widget.currentTier, isActive: true),
            const SizedBox(height: 4),
            Text(
              'Current',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),

        if (widget.nextTier != null) ...[
          const SizedBox(width: 20),
          Icon(Icons.arrow_forward, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 20),

          // Next tier
          Column(
            children: [
              _buildMiniFrame(widget.nextTier!, isActive: false),
              const SizedBox(height: 4),
              Text(
                'Next',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMainFrame() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _getTierGradient(),
        border: Border.all(color: _getTierBorderColor(), width: 4),
      ),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _getMaterialGradient(),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierIcon() {
    return Container(
      width: widget.size * 0.5,
      height: widget.size * 0.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.9),
      ),
      child: Icon(
        _getTierIcon(),
        size: widget.size * 0.25,
        color: _getTierColor(),
      ),
    );
  }

  Widget _buildGlowEffect() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size + 20,
          height: widget.size + 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _getTierColor().withOpacity(0.3 * _glowAnimation.value),
                blurRadius: 20 + (10 * _glowAnimation.value),
                spreadRadius: 5 + (5 * _glowAnimation.value),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSparkleEffects() {
    return AnimatedBuilder(
      animation: _sparkleAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size + 40, widget.size + 40),
          painter: SparklePainter(
            animation: _sparkleAnimation.value,
            color: _getTierColor(),
          ),
        );
      },
    );
  }

  Widget _buildUpgradeEffect() {
    return AnimatedBuilder(
      animation: _upgradeAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size * 2,
          height: widget.size * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withOpacity(0.8 * (1 - _upgradeAnimation.value)),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size + 40,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Colors.grey[200],
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnimation.value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [_getTierColor(), _getTierColor().withOpacity(0.7)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniFrame(BadgeTier tier, {required bool isActive}) {
    final size = widget.size * 0.6;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _getTierGradientForTier(tier),
        border: Border.all(
          color: _getTierColorForTier(tier).withOpacity(isActive ? 1.0 : 0.5),
          width: 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: _getTierColorForTier(tier).withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          _getTierDisplayNameForTier(tier).substring(0, 1),
          style: TextStyle(
            fontSize: size * 0.3,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressText() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        final percentage = (_progressAnimation.value * 100).toInt();
        return Text(
          widget.nextTier != null
              ? '$percentage% to ${_getTierDisplayNameForTier(widget.nextTier!)}'
              : 'Max Tier Reached',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }

  Widget _buildNextTierPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getTierColorForTier(widget.nextTier!).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getTierColorForTier(widget.nextTier!).withOpacity(0.3),
        ),
      ),
      child: Text(
        'Next: ${_getTierDisplayNameForTier(widget.nextTier!)}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _getTierColorForTier(widget.nextTier!),
        ),
      ),
    );
  }

  Widget _buildBenefitsTooltip() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getTierColor().withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_getTierIcon(), size: 16, color: _getTierColor()),
              const SizedBox(width: 6),
              Text(
                '${_getTierDisplayName()} Benefits',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _getTierColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.tierBenefits.map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 12, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      benefit,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleTooltip() {
    setState(() {
      _showTooltip = !_showTooltip;
    });
  }

  Color _getTierColor() => _getTierColorForTier(widget.currentTier);

  Color _getTierColorForTier(BadgeTier tier) {
    switch (tier) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.silver:
        return const Color(0xFFC0C0C0);
      case BadgeTier.gold:
        return const Color(0xFFFFD700);
      case BadgeTier.platinum:
        return const Color(0xFFE5E4E2);
      case BadgeTier.diamond:
        return const Color(0xFFB9F2FF);
    }
  }

  Color _getTierBorderColor() {
    return Color.lerp(_getTierColor(), Colors.black, 0.3)!;
  }

  LinearGradient _getTierGradient() =>
      _getTierGradientForTier(widget.currentTier);

  LinearGradient _getTierGradientForTier(BadgeTier tier) {
    final baseColor = _getTierColorForTier(tier);
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

  LinearGradient _getMaterialGradient() {
    final baseColor = _getTierColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.6),
        baseColor.withOpacity(0.3),
        baseColor.withOpacity(0.1),
      ],
    );
  }

  IconData _getTierIcon() {
    switch (widget.currentTier) {
      case BadgeTier.bronze:
        return Icons.military_tech;
      case BadgeTier.silver:
        return Icons.stars;
      case BadgeTier.gold:
        return Icons.workspace_premium;
      case BadgeTier.platinum:
        return Icons.diamond;
      case BadgeTier.diamond:
        return Icons.auto_awesome;
    }
  }

  String _getTierDisplayName() =>
      _getTierDisplayNameForTier(widget.currentTier);

  String _getTierDisplayNameForTier(BadgeTier tier) {
    return tier.toString().split('.').last.toUpperCase();
  }
}

class SparklePainter extends CustomPainter {
  final double animation;
  final Color color;

  SparklePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final sparkleCount = 8;

    for (int i = 0; i < sparkleCount; i++) {
      final angle = (i / sparkleCount) * 2 * math.pi;
      final radius = (size.width * 0.4) + (20 * animation);

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      final sparkleSize = 3 + (2 * math.sin(animation * math.pi));

      // Draw sparkle as a star
      _drawStar(canvas, Offset(x, y), sparkleSize, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final outerRadius = size;
    final innerRadius = size * 0.4;

    for (int i = 0; i < 10; i++) {
      final angle = (i * math.pi) / 5;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SparklePainter oldDelegate) =>
      animation != oldDelegate.animation;
}
