import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:confetti/confetti.dart';
import '../../../services/onboarding_gamification.dart' as gamification;
import '../../../../../themes/design_system.dart';
import 'onboarding_welcome_screen.dart'; // For providers

class OnboardingCompletionScreen extends ConsumerStatefulWidget {
  const OnboardingCompletionScreen({super.key});

  @override
  ConsumerState<OnboardingCompletionScreen> createState() =>
      _OnboardingCompletionScreenState();
}

class _OnboardingCompletionScreenState
    extends ConsumerState<OnboardingCompletionScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late ConfettiController _confettiController;

  bool _isLoading = false;
  gamification.CompletionCelebration? _celebration;
  List<gamification.Badge> _unlockedBadges = [];
  int _totalPoints = 0;
  double _profileStrength = 0.0;
  String _nextAction = '';

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _initializeCelebration();
  }

  Future<void> _initializeCelebration() async {
    final controller = ref.read(onboardingControllerProvider);
    final gamification = ref.read(onboardingGamificationProvider);
    final variant = controller.currentVariant ?? 'control';
    final userId = controller.currentUserId;

    if (userId != null) {
      // Get celebration data
      _celebration = await gamification.generateCompletionCelebration(userId);
      _unlockedBadges = await gamification.getUnlockedBadges(userId);
      _totalPoints = await gamification.getUserPoints(userId);
      _profileStrength = await gamification.calculateProfileStrength(userId);
      _nextAction = await gamification.getNextSuggestedAction(userId);

      setState(() {});

      // Start animations
      if (variant == 'gamified') {
        _confettiController.play();
      }

      _scaleController.forward();

      Future.delayed(const Duration(milliseconds: 300), () {
        _fadeController.forward();
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        _slideController.forward();
      });
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(onboardingControllerProvider);
    final variant = controller.currentVariant ?? 'control';

    return Scaffold(
      backgroundColor: DesignSystem.colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Confetti
            if (variant == 'gamified')
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: 1.57079633, // PI/2 (downward)
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  gravity: 0.1,
                  colors: [
                    DesignSystem.colors.primary,
                    DesignSystem.colors.secondary,
                    DesignSystem.colors.success,
                    DesignSystem.colors.warning,
                  ],
                ),
              ),

            // Content
            _buildContent(context, variant),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String variant) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              // Main celebration
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AnimatedBuilder(
                    animation: _scaleController,
                    builder: (context, child) {
                      return ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildMainCelebration(variant),
                      );
                    },
                  ),
                ),
              ),

              // Statistics section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: AnimatedBuilder(
                    animation: _fadeController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildStatistics(variant),
                      );
                    },
                  ),
                ),
              ),

              // Badges section (gamified only)
              if (variant == 'gamified')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: AnimatedBuilder(
                      animation: _slideController,
                      builder: (context, child) {
                        return SlideTransition(
                          position: _slideAnimation,
                          child: _buildBadgesSection(),
                        );
                      },
                    ),
                  ),
                ),

              // Special offers (if available)
              if (_celebration?.specialOffer != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: AnimatedBuilder(
                      animation: _fadeController,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildSpecialOffer(),
                        );
                      },
                    ),
                  ),
                ),

              // Next steps
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AnimatedBuilder(
                    animation: _slideController,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _slideAnimation,
                        child: _buildNextSteps(variant),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildActionButtons(variant),
        ),
      ],
    );
  }

  Widget _buildMainCelebration(String variant) {
    return Column(
      children: [
        const SizedBox(height: 32),

        // Celebration icon/emoji
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: DesignSystem.colors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              variant == 'gamified' ? '🏆' : '✨',
              style: const TextStyle(fontSize: 60),
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          variant == 'gamified'
              ? '🎉 Profile Complete!'
              : 'Welcome to Dabbler!',
          style: DesignSystem.typography.headlineLarge.copyWith(
            color: DesignSystem.colors.primary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        Text(
          variant == 'gamified'
              ? 'Congratulations! You\'ve earned $_totalPoints points and unlocked ${_unlockedBadges.length} badges.'
              : 'Your profile is now complete and ready to help you find amazing sports partners!',
          style: DesignSystem.typography.bodyLarge.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatistics(String variant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignSystem.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignSystem.colors.border),
      ),
      child: Column(
        children: [
          Text(
            'Profile Summary',
            style: DesignSystem.typography.titleLarge.copyWith(
              color: DesignSystem.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 20),

          // Profile strength indicator
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Strength',
                      style: DesignSystem.typography.bodyMedium.copyWith(
                        color: DesignSystem.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: _profileStrength / 100,
                            backgroundColor: DesignSystem.colors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getStrengthColor(_profileStrength),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_profileStrength.toInt()}%',
                          style: DesignSystem.typography.titleMedium.copyWith(
                            color: _getStrengthColor(_profileStrength),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (variant == 'gamified') ...[
            const SizedBox(height: 20),

            // Points and badges
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: LucideIcons.zap,
                    label: 'Points Earned',
                    value: '$_totalPoints',
                    color: DesignSystem.colors.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: LucideIcons.award,
                    label: 'Badges Unlocked',
                    value: '${_unlockedBadges.length}',
                    color: DesignSystem.colors.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: DesignSystem.typography.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: DesignSystem.typography.bodySmall.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection() {
    if (_unlockedBadges.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignSystem.colors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DesignSystem.colors.success.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.award,
                color: DesignSystem.colors.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'New Badges Unlocked!',
                style: DesignSystem.typography.titleMedium.copyWith(
                  color: DesignSystem.colors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _unlockedBadges
                .map((badge) => _buildBadgeItem(badge))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(gamification.Badge badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DesignSystem.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: DesignSystem.colors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🏆', // Default trophy icon for badges
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 6),
          Text(
            badge.name,
            style: DesignSystem.typography.bodySmall.copyWith(
              color: DesignSystem.colors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialOffer() {
    if (_celebration?.specialOffer == null) return const SizedBox();

    final offer = _celebration!.specialOffer!;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DesignSystem.colors.primary.withValues(alpha: 0.1),
            DesignSystem.colors.secondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DesignSystem.colors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.gift,
                color: DesignSystem.colors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  offer.title,
                  style: DesignSystem.typography.titleMedium.copyWith(
                    color: DesignSystem.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            offer.description,
            style: DesignSystem.typography.bodyMedium.copyWith(
              color: DesignSystem.colors.textSecondary,
            ),
          ),

          ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: DesignSystem.colors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Expires ${_formatDate(offer.expiresAt)}',
                style: DesignSystem.typography.bodySmall.copyWith(
                  color: DesignSystem.colors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextSteps(String variant) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignSystem.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignSystem.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s Next?',
            style: DesignSystem.typography.titleMedium.copyWith(
              color: DesignSystem.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          _buildNextStepItem(
            icon: LucideIcons.search,
            title: 'Find Your First Game',
            subtitle: 'Browse nearby games and join your first match',
            isRecommended: true,
          ),

          _buildNextStepItem(
            icon: LucideIcons.users,
            title: 'Connect with Players',
            subtitle: 'Follow interesting players and build your network',
          ),

          _buildNextStepItem(
            icon: LucideIcons.calendar,
            title: 'Create a Game',
            subtitle: 'Host your own game and invite others to join',
          ),

          if (variant == 'gamified' && _nextAction.isNotEmpty)
            _buildNextStepItem(
              icon: LucideIcons.target,
              title: 'Personalized Suggestion',
              subtitle: _nextAction,
              color: DesignSystem.colors.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildNextStepItem({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isRecommended = false,
    Color? color,
  }) {
    final itemColor = color ?? DesignSystem.colors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRecommended
            ? DesignSystem.colors.primary.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isRecommended
            ? Border.all(
                color: DesignSystem.colors.primary.withValues(alpha: 0.2),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: itemColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: itemColor, size: 20),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: DesignSystem.typography.titleSmall.copyWith(
                          color: itemColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isRecommended)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: DesignSystem.colors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Recommended',
                          style: DesignSystem.typography.bodySmall.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: DesignSystem.typography.bodySmall.copyWith(
                    color: DesignSystem.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          Icon(
            LucideIcons.chevronRight,
            color: DesignSystem.colors.textSecondary,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String variant) {
    return Column(
      children: [
        // Main CTA
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _startExploring(),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignSystem.colors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    '🚀 Start Playing!',
                    style: DesignSystem.typography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 12),

        // Secondary action
        TextButton(
          onPressed: () => _goToProfile(),
          child: Text(
            'View My Profile',
            style: DesignSystem.typography.titleSmall.copyWith(
              color: DesignSystem.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStrengthColor(double strength) {
    if (strength >= 80) return DesignSystem.colors.success;
    if (strength >= 60) return DesignSystem.colors.warning;
    return DesignSystem.colors.error;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) return 'today';
    if (difference == 1) return 'tomorrow';
    return 'in $difference days';
  }

  Future<void> _startExploring() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final controller = ref.read(onboardingControllerProvider);

      // Mark onboarding as fully completed
      await controller.markOnboardingCompleted();

      // Navigate to main app
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: DesignSystem.colors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goToProfile() {
    if (mounted) {
      context.go('/profile');
    }
  }
}
