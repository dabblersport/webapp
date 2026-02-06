import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Reusable Game Card Widget for displaying upcoming games with animated background
class GameCard extends StatefulWidget {
  const GameCard({
    super.key,
    required this.countdownLabel,
    required this.title,
    required this.date,
    required this.timeRange,
    required this.location,
    required this.avatarUrls,
    required this.othersCount,
    this.onTap,
  });

  final String countdownLabel;
  final String title;
  final String date;
  final String timeRange;
  final String location;
  final List<String> avatarUrls;
  final int othersCount;
  final VoidCallback? onTap;

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF1E0E33);
    final secondaryColor = isDark
        ? Colors.white.withOpacity(0.70)
        : const Color(0xFF1E0E33).withOpacity(0.70);
    final tertiaryColor = isDark
        ? Colors.white.withOpacity(0.90)
        : const Color(0xFF1E0E33).withOpacity(0.90);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              child: CustomPaint(
                painter: _GameCardBackgroundPainter(
                  animationValue: _animation.value,
                  isDark: isDark,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: "Upcoming Game" + countdown chip
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Iconsax.calendar_copy,
                                  size: 18,
                                  color: tertiaryColor,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Upcoming Game',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w400,
                                      fontSize: 14,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _OutlinePill(
                            icon: Iconsax.timer_1_copy,
                            label: widget.countdownLabel,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Title
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 22,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Date and Time row
                      Row(
                        children: [
                          Icon(
                            Iconsax.clock_copy,
                            size: 18,
                            color: tertiaryColor,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${widget.date} - ${widget.timeRange}',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w400,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Location row
                      Row(
                        children: [
                          Icon(
                            Iconsax.location_copy,
                            size: 18,
                            color: tertiaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.location,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Avatars + "+5 others"
                      Row(
                        children: [
                          _AvatarStack(urls: widget.avatarUrls),
                          const SizedBox(width: 10),
                          Text(
                            '+${widget.othersCount} others',
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 14.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for animated multi-layered gradient background
/// Animates gradient positions and intensities for a living, breathing effect
class _GameCardBackgroundPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  _GameCardBackgroundPainter({
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (isDark) {
      _paintDarkTheme(canvas, size, rect);
    } else {
      _paintLightTheme(canvas, size, rect);
    }
  }

  /// Paint dark theme gradient background
  void _paintDarkTheme(Canvas canvas, Size size, Rect rect) {
    // Base color #1E0E33
    final basePaint = Paint()..color = const Color(0xFF1E0E33);
    canvas.drawRect(rect, basePaint);

    // Animate gradient positions with a breathing effect
    final breathe = animationValue * 0.15; // Subtle 15% movement

    // Layer 1: Animated linear gradient (reduced green opacity)
    final linearPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(0.95 - breathe, 0.35 + breathe),
        end: Alignment(-0.95 + breathe, -0.35 - breathe),
        colors: _createSmoothGradient(
          Color.lerp(
            const Color(0x3300FF9A),
            const Color.fromARGB(72, 0, 255, 153),
            animationValue * 0.3,
          )!,
          const Color(0x0000FF9A),
          steps: 12,
        ),
        stops: _createSmoothStops(0.0737, 0.5453, steps: 12),
      ).createShader(rect);
    canvas.drawRect(rect, linearPaint);

    // Layer 2: Animated radial gradient at bottom-left
    final radial2Paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(-1.0 + (breathe * 0.5), 1.0 - (breathe * 0.3)),
        radius: 1.4179 + (breathe * 0.2),
        colors: _createSmoothGradient(
          Color.lerp(
            const Color(0x800BB8DD),
            const Color(0x9F0BB8DD),
            animationValue * 0.25,
          )!,
          const Color(0x000BB8DD),
          steps: 10,
        ),
        stops: _createSmoothStops(0.0, 0.4471, steps: 10),
      ).createShader(rect);
    canvas.drawRect(rect, radial2Paint);

    // Layer 3: Animated radial gradient at right side (main glow)
    final radial1Paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(1.0 - (breathe * 0.4), 0.4752 + (breathe * 0.5)),
        radius: 1.6781 + (breathe * 0.3),
        colors: _createSmoothGradient(
          Color.lerp(
            const Color(0xFF5CFF00),
            const Color(0xFFAAFF55),
            animationValue * 0.2,
          )!,
          const Color(0x001E0E33),
          steps: 15,
        ),
        stops: _createSmoothStops(0.0, 1.0, steps: 15),
      ).createShader(rect);
    canvas.drawRect(rect, radial1Paint);
  }

  /// Paint light theme gradient background with vibrant gradients
  void _paintLightTheme(Canvas canvas, Size size, Rect rect) {
    // Base color - light violet similar to app background
    final basePaint = Paint()..color = const Color(0xFFF5EDFF);
    canvas.drawRect(rect, basePaint);

    // Animate gradient positions with a breathing effect
    final breathe = animationValue * 0.15; // Subtle 15% movement

    // Layer 1: Animated linear gradient (vibrant mint/teal)
    final linearPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(0.95 - breathe, 0.35 + breathe),
        end: Alignment(-0.95 + breathe, -0.35 - breathe),
        colors: _createSmoothGradient(
          Color.lerp(
            const Color(0x6600D9A3),
            const Color(0x8000D9A3),
            animationValue * 0.3,
          )!,
          const Color(0x0000D9A3),
          steps: 12,
        ),
        stops: _createSmoothStops(0.0737, 0.5453, steps: 12),
      ).createShader(rect);
    canvas.drawRect(rect, linearPaint);

    // Layer 2: Animated radial gradient at bottom-left (vibrant cyan/blue)
    final radial2Paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(-1.0 + (breathe * 0.5), 1.0 - (breathe * 0.3)),
        radius: 1.4179 + (breathe * 0.2),
        colors: _createSmoothGradient(
          Color.lerp(
            const Color(0x8009A8DD),
            const Color(0x9F09A8DD),
            animationValue * 0.25,
          )!,
          const Color(0x0009A8DD),
          steps: 10,
        ),
        stops: _createSmoothStops(0.0, 0.4471, steps: 10),
      ).createShader(rect);
    canvas.drawRect(rect, radial2Paint);

    // Layer 3: Animated radial gradient at right side (vibrant violet/purple)
    final radial1Paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(1.0 - (breathe * 0.4), 0.4752 + (breathe * 0.5)),
        radius: 1.6781 + (breathe * 0.3),
        colors: _createSmoothGradient(
          Color.lerp(
            const Color(0xFFB88FFF),
            const Color(0xFFD4B3FF),
            animationValue * 0.2,
          )!,
          const Color(0x00F5EDFF),
          steps: 15,
        ),
        stops: _createSmoothStops(0.0, 1.0, steps: 15),
      ).createShader(rect);
    canvas.drawRect(rect, radial1Paint);
  }

  /// Creates smooth color transitions using exponential easing
  List<Color> _createSmoothGradient(
    Color start,
    Color end, {
    required int steps,
  }) {
    final colors = <Color>[];
    for (int i = 0; i < steps; i++) {
      final t = i / (steps - 1);
      // Use quadratic easing out for natural falloff
      final easedT = 1 - (1 - t) * (1 - t);
      colors.add(Color.lerp(start, end, easedT)!);
    }
    return colors;
  }

  /// Creates smooth stop positions with easing
  List<double> _createSmoothStops(
    double start,
    double end, {
    required int steps,
  }) {
    final stops = <double>[];
    for (int i = 0; i < steps; i++) {
      final t = i / (steps - 1);
      // Use quadratic easing for distribution
      final easedT = 1 - (1 - t) * (1 - t);
      stops.add(start + (end - start) * easedT);
    }
    return stops;
  }

  @override
  bool shouldRepaint(_GameCardBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isDark != isDark;
  }
}

class _OutlinePill extends StatelessWidget {
  const _OutlinePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillColor = isDark ? Colors.white : const Color(0xFF1E0E33);
    final backgroundColor = isDark
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFF1E0E33).withOpacity(0.08);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.85)
        : const Color(0xFF1E0E33).withOpacity(0.90);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: pillColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: pillColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    const double radius = 14;
    const double overlap = 18;

    return SizedBox(
      height: radius * 2,
      width: urls.isEmpty ? 0 : (overlap * (urls.length - 1) + radius * 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < urls.length; i++)
            Positioned(
              left: i * overlap,
              child: CircleAvatar(
                radius: radius,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: radius - 1.5,
                  backgroundImage: NetworkImage(urls[i]),
                  onBackgroundImageError: (exception, stackTrace) {
                    // Handle image loading error silently
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade300,
                    ),
                    child: Icon(
                      Iconsax.user_copy,
                      size: radius,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
