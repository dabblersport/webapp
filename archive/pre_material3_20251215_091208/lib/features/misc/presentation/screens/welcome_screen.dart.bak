import 'package:flutter/material.dart';
import 'package:dabbler/themes/design_system.dart';

import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dabbler/utils/constants/app_constants.dart';

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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      const Spacer(),

                      // Success Icon with pulse animation
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (0.1 * _animationController.value),
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: DS.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.check,
                                size: 60,
                                color: DS.primary,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Welcome Message
                      Text(
                        'Welcome to Dabbler!',
                        style: DS.headline.copyWith(
                          fontWeight: FontWeight.w700,
                          color: DS.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      // Personalized greeting [[memory:3805984]]
                      Text(
                        'Hi ${widget.displayName}! 👋',
                        style: DS.subtitle.copyWith(
                          color: DS.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Your account has been created successfully.\nGet ready to discover amazing sports experiences!',
                        style: DS.body.copyWith(color: DS.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 48),

                      // Skip to home button (optional)
                      TextButton(
                        onPressed: () => context.go('/home'),
                        child: Text(
                          'Continue to Home',
                          style: DS.body.copyWith(
                            color: DS.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Progress indicator
                      LinearProgressIndicator(
                        backgroundColor: DS.border.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(DS.primary),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Taking you to your home screen...',
                        style: DS.caption.copyWith(color: DS.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
