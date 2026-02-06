import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Confetti particle data
class ConfettiParticle {
  final Offset position;
  final Offset velocity;
  final Color color;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final ConfettiShape shape;
  final double life;
  final double maxLife;

  ConfettiParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.shape,
    required this.life,
    required this.maxLife,
  });

  ConfettiParticle copyWith({
    Offset? position,
    Offset? velocity,
    Color? color,
    double? size,
    double? rotation,
    double? rotationSpeed,
    ConfettiShape? shape,
    double? life,
    double? maxLife,
  }) {
    return ConfettiParticle(
      position: position ?? this.position,
      velocity: velocity ?? this.velocity,
      color: color ?? this.color,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      rotationSpeed: rotationSpeed ?? this.rotationSpeed,
      shape: shape ?? this.shape,
      life: life ?? this.life,
      maxLife: maxLife ?? this.maxLife,
    );
  }

  double get alpha => (life / maxLife).clamp(0.0, 1.0);
  bool get isDead => life <= 0;
}

/// Confetti shapes enum
enum ConfettiShape { circle, square, triangle, star, heart, diamond }

/// Confetti animation configuration
class ConfettiConfig {
  final List<Color> colors;
  final List<ConfettiShape> shapes;
  final double minSize;
  final double maxSize;
  final double minSpeed;
  final double maxSpeed;
  final double gravity;
  final double drag;
  final int particleCount;
  final Duration duration;
  final double spread;
  final double minLife;
  final double maxLife;
  final bool enablePhysics;

  const ConfettiConfig({
    this.colors = const [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
      Colors.pink,
    ],
    this.shapes = ConfettiShape.values,
    this.minSize = 4.0,
    this.maxSize = 12.0,
    this.minSpeed = 200.0,
    this.maxSpeed = 600.0,
    this.gravity = 500.0,
    this.drag = 0.98,
    this.particleCount = 150,
    this.duration = const Duration(seconds: 3),
    this.spread = math.pi / 3,
    this.minLife = 2.0,
    this.maxLife = 4.0,
    this.enablePhysics = true,
  });

  ConfettiConfig copyWith({
    List<Color>? colors,
    List<ConfettiShape>? shapes,
    double? minSize,
    double? maxSize,
    double? minSpeed,
    double? maxSpeed,
    double? gravity,
    double? drag,
    int? particleCount,
    Duration? duration,
    double? spread,
    double? minLife,
    double? maxLife,
    bool? enablePhysics,
  }) {
    return ConfettiConfig(
      colors: colors ?? this.colors,
      shapes: shapes ?? this.shapes,
      minSize: minSize ?? this.minSize,
      maxSize: maxSize ?? this.maxSize,
      minSpeed: minSpeed ?? this.minSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      gravity: gravity ?? this.gravity,
      drag: drag ?? this.drag,
      particleCount: particleCount ?? this.particleCount,
      duration: duration ?? this.duration,
      spread: spread ?? this.spread,
      minLife: minLife ?? this.minLife,
      maxLife: maxLife ?? this.maxLife,
      enablePhysics: enablePhysics ?? this.enablePhysics,
    );
  }
}

/// Confetti animation widget
class ConfettiAnimation extends StatefulWidget {
  final ConfettiConfig config;
  final bool isPlaying;
  final VoidCallback? onComplete;
  final Offset? origin;
  final Widget? child;

  const ConfettiAnimation({
    super.key,
    this.config = const ConfettiConfig(),
    required this.isPlaying,
    this.onComplete,
    this.origin,
    this.child,
  });

  @override
  State<ConfettiAnimation> createState() => _ConfettiAnimationState();
}

class _ConfettiAnimationState extends State<ConfettiAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  late Ticker _physicsTicker;
  DateTime? _lastPhysicsUpdate;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initializeController();
    _initializePhysics();
  }

  void _initializeController() {
    _controller = AnimationController(
      duration: widget.config.duration,
      vsync: this,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  void _initializePhysics() {
    _physicsTicker = createTicker(_updatePhysics);
    if (widget.isPlaying) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _generateParticles();
    _controller.forward(from: 0);
    _physicsTicker.start();
    _lastPhysicsUpdate = DateTime.now();
  }

  void _stopAnimation() {
    _controller.stop();
    _physicsTicker.stop();
    setState(() {
      _particles.clear();
    });
  }

  void _generateParticles() {
    _particles.clear();
    final size = MediaQuery.of(context).size;
    final origin = widget.origin ?? Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < widget.config.particleCount; i++) {
      final angle = (_random.nextDouble() - 0.5) * widget.config.spread;
      final speed =
          widget.config.minSpeed +
          _random.nextDouble() *
              (widget.config.maxSpeed - widget.config.minSpeed);

      final velocity = Offset(
        math.cos(angle - math.pi / 2) * speed,
        math.sin(angle - math.pi / 2) * speed,
      );

      final particle = ConfettiParticle(
        position: origin,
        velocity: velocity,
        color:
            widget.config.colors[_random.nextInt(widget.config.colors.length)],
        size:
            widget.config.minSize +
            _random.nextDouble() *
                (widget.config.maxSize - widget.config.minSize),
        rotation: _random.nextDouble() * 2 * math.pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 10,
        shape:
            widget.config.shapes[_random.nextInt(widget.config.shapes.length)],
        life:
            widget.config.minLife +
            _random.nextDouble() *
                (widget.config.maxLife - widget.config.minLife),
        maxLife: widget.config.maxLife,
      );

      _particles.add(particle);
    }
  }

  void _updatePhysics(Duration elapsed) {
    if (!widget.config.enablePhysics) return;

    final now = DateTime.now();
    final deltaTime = _lastPhysicsUpdate != null
        ? now.difference(_lastPhysicsUpdate!).inMicroseconds / 1000000.0
        : 1 / 60.0;
    _lastPhysicsUpdate = now;

    // Clamp delta time to prevent large jumps
    final clampedDelta = deltaTime.clamp(0.0, 1 / 30.0);

    for (int i = _particles.length - 1; i >= 0; i--) {
      final particle = _particles[i];

      // Update life
      final newLife = particle.life - clampedDelta;
      if (newLife <= 0) {
        _particles.removeAt(i);
        continue;
      }

      // Apply physics
      var newVelocity = particle.velocity;

      // Apply gravity
      newVelocity = Offset(
        newVelocity.dx,
        newVelocity.dy + widget.config.gravity * clampedDelta,
      );

      // Apply drag
      newVelocity = newVelocity * widget.config.drag;

      // Update position
      final newPosition = particle.position + newVelocity * clampedDelta;

      // Update rotation
      final newRotation =
          particle.rotation + particle.rotationSpeed * clampedDelta;

      _particles[i] = particle.copyWith(
        position: newPosition,
        velocity: newVelocity,
        rotation: newRotation,
        life: newLife,
      );
    }

    setState(() {});

    // Stop animation when no particles remain
    if (_particles.isEmpty && _controller.isAnimating) {
      _controller.stop();
      _physicsTicker.stop();
      widget.onComplete?.call();
    }
  }

  @override
  void didUpdateWidget(ConfettiAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _physicsTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.child != null) widget.child!,
        if (widget.isPlaying)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ConfettiPainter(
                  particles: _particles,
                  animation: _controller,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Confetti painter
class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final Animation<double> animation;

  ConfettiPainter({required this.particles, required this.animation})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(particle.position.dx, particle.position.dy);
      canvas.rotate(particle.rotation);

      _drawShape(canvas, particle.shape, particle.size, paint);

      canvas.restore();
    }
  }

  void _drawShape(
    Canvas canvas,
    ConfettiShape shape,
    double size,
    Paint paint,
  ) {
    switch (shape) {
      case ConfettiShape.circle:
        canvas.drawCircle(Offset.zero, size / 2, paint);
        break;

      case ConfettiShape.square:
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: size, height: size),
          paint,
        );
        break;

      case ConfettiShape.triangle:
        final path = Path();
        path.moveTo(0, -size / 2);
        path.lineTo(-size / 2, size / 2);
        path.lineTo(size / 2, size / 2);
        path.close();
        canvas.drawPath(path, paint);
        break;

      case ConfettiShape.star:
        _drawStar(canvas, size, paint);
        break;

      case ConfettiShape.heart:
        _drawHeart(canvas, size, paint);
        break;

      case ConfettiShape.diamond:
        final path = Path();
        path.moveTo(0, -size / 2);
        path.lineTo(size / 2, 0);
        path.lineTo(0, size / 2);
        path.lineTo(-size / 2, 0);
        path.close();
        canvas.drawPath(path, paint);
        break;
    }
  }

  void _drawStar(Canvas canvas, double size, Paint paint) {
    final path = Path();
    const points = 5;
    const outerRadius = 1.0;
    const innerRadius = 0.4;

    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi) / points;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = math.cos(angle - math.pi / 2) * radius * size / 2;
      final y = math.sin(angle - math.pi / 2) * radius * size / 2;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, double size, Paint paint) {
    final path = Path();
    final heartSize = size / 2;

    // Heart shape using bezier curves
    path.moveTo(0, heartSize * 0.3);

    // Left side
    path.cubicTo(
      -heartSize * 0.5,
      -heartSize * 0.2,
      -heartSize * 0.8,
      heartSize * 0.1,
      0,
      heartSize * 0.8,
    );

    // Right side
    path.cubicTo(
      heartSize * 0.8,
      heartSize * 0.1,
      heartSize * 0.5,
      -heartSize * 0.2,
      0,
      heartSize * 0.3,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! ConfettiPainter ||
        oldDelegate.particles != particles;
  }
}

/// Preset confetti configurations
class ConfettiPresets {
  static const ConfettiConfig celebration = ConfettiConfig(
    colors: [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
    ],
    particleCount: 200,
    duration: Duration(seconds: 4),
    minSpeed: 300.0,
    maxSpeed: 800.0,
    spread: math.pi / 2,
  );

  static const ConfettiConfig gentle = ConfettiConfig(
    colors: [
      Color(0xFFFFB6C1),
      Color(0xFFE6E6FA),
      Color(0xFFF0E68C),
      Color(0xFF98FB98),
    ],
    particleCount: 50,
    duration: Duration(seconds: 6),
    minSpeed: 100.0,
    maxSpeed: 300.0,
    gravity: 200.0,
    minSize: 6.0,
    maxSize: 10.0,
  );

  static const ConfettiConfig explosion = ConfettiConfig(
    colors: [Colors.orange, Colors.red, Colors.yellow],
    shapes: [ConfettiShape.star, ConfettiShape.diamond],
    particleCount: 300,
    duration: Duration(seconds: 2),
    minSpeed: 500.0,
    maxSpeed: 1200.0,
    spread: math.pi,
    minSize: 8.0,
    maxSize: 16.0,
  );

  static const ConfettiConfig hearts = ConfettiConfig(
    colors: [Colors.pink, Colors.red, Color(0xFFFF69B4)],
    shapes: [ConfettiShape.heart],
    particleCount: 100,
    duration: Duration(seconds: 5),
    minSpeed: 200.0,
    maxSpeed: 500.0,
    minSize: 10.0,
    maxSize: 20.0,
  );

  static const ConfettiConfig goldRush = ConfettiConfig(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFFF00)],
    shapes: [ConfettiShape.star, ConfettiShape.circle],
    particleCount: 150,
    duration: Duration(seconds: 3),
    minSpeed: 400.0,
    maxSpeed: 700.0,
    minSize: 8.0,
    maxSize: 14.0,
  );
}

/// Confetti controller for programmatic control
class ConfettiController extends ChangeNotifier {
  bool _isPlaying = false;
  ConfettiConfig _config = const ConfettiConfig();

  bool get isPlaying => _isPlaying;
  ConfettiConfig get config => _config;

  void play([ConfettiConfig? newConfig]) {
    if (newConfig != null) {
      _config = newConfig;
    }
    _isPlaying = true;
    notifyListeners();
  }

  void stop() {
    _isPlaying = false;
    notifyListeners();
  }

  void updateConfig(ConfettiConfig newConfig) {
    _config = newConfig;
    notifyListeners();
  }

  void playPreset(ConfettiConfig preset) {
    play(preset);
  }
}
