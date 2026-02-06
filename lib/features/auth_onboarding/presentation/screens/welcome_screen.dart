import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/design_system/design_system.dart';

class WelcomeScreen extends StatefulWidget {
  final String displayName;

  const WelcomeScreen({super.key, required this.displayName});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
          ),
        );

    // Start animation
    _animationController.forward();

    // Auto-navigate to home after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SingleSectionLayout(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (screenHeight - topPadding - bottomPadding - 48)
                      .clamp(0.0, double.infinity)
                      .toDouble(),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),

                    // Dabbler logo
                    Center(
                      child: SvgPicture.asset(
                        'assets/images/dabbler_logo.svg',
                        width: 100,
                        height: 110,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),

                    SizedBox(height: 16.0),

                    // Dabbler text logo
                    Center(
                      child: SvgPicture.asset(
                        'assets/images/dabbler_text_logo.svg',
                        width: 130,
                        height: 25,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),

                    SizedBox(height: 24.0),

                    // Success Icon with pulse animation
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (0.1 * _animationController.value),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC18FFF).withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFC18FFF),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 50,
                              color: Color(0xFFC18FFF),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 24.0),

                    // Welcome Message
                    Text(
                      'Welcome to Dabbler!',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 12.0),

                    // Personalized greeting
                    Text(
                      'Hi ${widget.displayName}! 👋',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFFC18FFF),
                            fontWeight: FontWeight.w500,
                          ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 12.0),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Your account has been created successfully.\nGet ready to discover amazing sports experiences!',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const Spacer(),

                    // Progress indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFC18FFF),
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    SizedBox(height: 12.0),

                    Text(
                      'Taking you to your home screen...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 12.0),

                    // Skip button
                    TextButton(
                      onPressed: () => context.go('/home'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: const Text('Continue to Home'),
                    ),

                    SizedBox(height: 24.0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
