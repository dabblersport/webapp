import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/onboarding_controller.dart';
import '../../../services/onboarding_gamification.dart';
import 'package:dabbler/themes/design_system.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

// Simple Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final onboardingControllerProvider =
    ChangeNotifierProvider<OnboardingController>((ref) {
      final supabase = ref.read(supabaseClientProvider);
      return OnboardingController(supabase: supabase);
    });

final onboardingGamificationProvider = Provider<OnboardingGamification>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return OnboardingGamification(supabase: supabase);
});

class ProfileOnboardingWelcomeScreen extends ConsumerStatefulWidget {
  const ProfileOnboardingWelcomeScreen({super.key});

  @override
  ConsumerState<ProfileOnboardingWelcomeScreen> createState() =>
      _ProfileOnboardingWelcomeScreenState();
}

class _ProfileOnboardingWelcomeScreenState
    extends ConsumerState<ProfileOnboardingWelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  String _socialProofMessage = '';

  @override
  void initState() {
    super.initState();

    // Main animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Pulse animation for CTA button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );

    _loadSocialProof();

    // Start animations
    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadSocialProof() async {
    final controller = ref.read(onboardingControllerProvider);
    final message = await controller.getSocialProofMessage();
    if (mounted) {
      setState(() {
        _socialProofMessage = message;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(onboardingControllerProvider);
    final variant = controller.currentVariant ?? 'control';

    return Scaffold(
      backgroundColor: DesignSystem.colors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildContent(context, variant),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String variant) {
    return CustomScrollView(
      slivers: [
        // Skip button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showSkipWarning(context),
                  style: TextButton.styleFrom(
                    foregroundColor: DesignSystem.colors.textSecondary,
                  ),
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ),
        ),

        // Main content
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),

                // Hero illustration
                _buildHeroSection(variant),

                const SizedBox(height: 48),

                // Welcome content
                _buildWelcomeContent(variant),

                const SizedBox(height: 32),

                // Benefits list
                _buildBenefitsList(variant),

                const Spacer(),

                // Social proof
                if (_socialProofMessage.isNotEmpty) _buildSocialProof(),

                const SizedBox(height: 24),

                // CTA Button
                _buildCTAButton(variant),

                const SizedBox(height: 16),

                // Progress indicator
                _buildProgressIndicator(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection(String variant) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final heroColor = isDarkMode
        ? const Color(0xFF4A148C)
        : const Color(0xFFE0C7FF);

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: heroColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Icon(
        variant == 'gamified' ? Icons.emoji_events : Icons.person_add,
        size: 80,
        color: DesignSystem.colors.primary,
      ),
    );
  }

  Widget _buildWelcomeContent(String variant) {
    return Column(
      children: [
        Text(
          variant == 'gamified'
              ? '🎯 Ready to Level Up?'
              : variant == 'minimal'
              ? 'Complete Your Profile'
              : 'Welcome to Your Journey!',
          style: DesignSystem.typography.headlineLarge.copyWith(
            color: DesignSystem.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        Text(
          variant == 'gamified'
              ? 'Complete your profile, earn points, unlock badges, and join the most exciting sports community!'
              : variant == 'minimal'
              ? 'A few quick steps to personalize your experience and find perfect games.'
              : 'Let\'s set up your profile so you can discover amazing games and connect with fellow players in your area.',
          style: DesignSystem.typography.bodyLarge.copyWith(
            color: DesignSystem.colors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBenefitsList(String variant) {
    final benefits = variant == 'gamified'
        ? [
            BenefitItem(
              icon: Icons.emoji_events,
              title: 'Earn Points & Badges',
              description: 'Get rewarded for every action you take',
            ),
            BenefitItem(
              icon: Icons.gps_fixed,
              title: 'Perfect Game Matches',
              description: 'AI-powered recommendations just for you',
            ),
            BenefitItem(
              icon: Icons.group,
              title: 'Connect & Compete',
              description: 'Join a community of passionate players',
            ),
          ]
        : variant == 'minimal'
        ? [
            BenefitItem(
              icon: Icons.search,
              title: 'Find Games',
              description: 'Discover games near you',
            ),
            BenefitItem(
              icon: Icons.calendar_today,
              title: 'Easy Booking',
              description: 'Book with one tap',
            ),
          ]
        : [
            BenefitItem(
              icon: Icons.location_city,
              title: 'Local Games',
              description: 'Find games in your neighborhood',
            ),
            BenefitItem(
              icon: Icons.access_time,
              title: 'Flexible Scheduling',
              description: 'Games that fit your schedule',
            ),
            BenefitItem(
              icon: Icons.shield,
              title: 'Safe & Verified',
              description: 'Play with trusted community members',
            ),
          ];

    return Column(
      children: benefits.map((benefit) => _buildBenefitItem(benefit)).toList(),
    );
  }

  Widget _buildBenefitItem(BenefitItem benefit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: DesignSystem.colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              benefit.icon,
              color: DesignSystem.colors.primary,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.title,
                  style: DesignSystem.typography.titleMedium.copyWith(
                    color: DesignSystem.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  benefit.description,
                  style: DesignSystem.typography.bodyMedium.copyWith(
                    color: DesignSystem.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialProof() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DesignSystem.colors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignSystem.colors.success.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group, color: DesignSystem.colors.success, size: 16),

          const SizedBox(width: 8),

          Text(
            _socialProofMessage,
            style: DesignSystem.typography.bodySmall.copyWith(
              color: DesignSystem.colors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTAButton(String variant) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _startOnboarding(),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignSystem.colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    variant == 'gamified'
                        ? 'Start Earning Points!'
                        : variant == 'minimal'
                        ? 'Get Started'
                        : 'Let\'s Get Started',
                    style: DesignSystem.typography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Text(
          'Step 1 of 4',
          style: DesignSystem.typography.bodySmall.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
        ),

        const SizedBox(height: 8),

        LinearProgressIndicator(
          value: 0.0,
          backgroundColor: DesignSystem.colors.border,
          valueColor: AlwaysStoppedAnimation<Color>(
            DesignSystem.colors.primary,
          ),
        ),
      ],
    );
  }

  void _startOnboarding() {
    final controller = ref.read(onboardingControllerProvider);
    controller.startOnboarding();
    context.go(RoutePaths.onboardingBasicInfo);
  }

  void _showSkipWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Skip Profile Setup?',
          style: DesignSystem.typography.headlineSmall.copyWith(
            color: DesignSystem.colors.textPrimary,
          ),
        ),
        content: Text(
          'You can always complete your profile later, but having a complete profile helps you:\n\n• Find better game matches\n• Connect with other players\n• Get personalized recommendations',
          style: DesignSystem.typography.bodyMedium.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Continue Setup',
              style: TextStyle(color: DesignSystem.colors.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignSystem.colors.textSecondary,
            ),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}

class BenefitItem {
  final IconData icon;
  final String title;
  final String description;

  BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
