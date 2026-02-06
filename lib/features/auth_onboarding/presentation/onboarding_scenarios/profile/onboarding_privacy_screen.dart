import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../themes/design_system.dart';
import '../../../../../utils/constants/route_constants.dart';
import 'onboarding_welcome_screen.dart'; // For providers

class OnboardingPrivacyScreen extends ConsumerStatefulWidget {
  const OnboardingPrivacyScreen({super.key});

  @override
  ConsumerState<OnboardingPrivacyScreen> createState() =>
      _OnboardingPrivacyScreenState();
}

class _OnboardingPrivacyScreenState
    extends ConsumerState<OnboardingPrivacyScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Privacy settings
  String _profileVisibility = 'public';
  bool _showRealName = true;
  bool _showAge = false;
  bool _showLocation = true;
  bool _showSportsHistory = true;
  bool _allowMessages = true;
  bool _allowGameInvites = true;
  bool _showOnlineStatus = false;
  String _dataRetention = '1_year';
  bool _allowAnalytics = true;
  bool _marketingEmails = false;

  bool _isLoading = false;
  bool _hasReviewedPrivacy = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
    _loadExistingData();
  }

  void _loadExistingData() {
    final controller = ref.read(onboardingControllerProvider);
    final existingData = controller.progress?.stepData['step_4'];

    if (existingData != null) {
      _profileVisibility = existingData['profile_visibility'] ?? 'public';
      _showRealName = existingData['show_real_name'] ?? true;
      _showAge = existingData['show_age'] ?? false;
      _showLocation = existingData['show_location'] ?? true;
      _showSportsHistory = existingData['show_sports_history'] ?? true;
      _allowMessages = existingData['allow_messages'] ?? true;
      _allowGameInvites = existingData['allow_game_invites'] ?? true;
      _showOnlineStatus = existingData['show_online_status'] ?? false;
      _dataRetention = existingData['data_retention'] ?? '1_year';
      _allowAnalytics = existingData['allow_analytics'] ?? true;
      _marketingEmails = existingData['marketing_emails'] ?? false;
      _hasReviewedPrivacy = existingData['privacy_reviewed'] ?? false;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(onboardingControllerProvider);
    final variant = controller.currentVariant ?? 'control';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.go(RoutePaths.onboardingPreferences),
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _skipStep(),
            child: Text(
              'Skip',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: _buildHeroSection(variant),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Privacy sections
                    _buildProfileVisibilitySection(),
                    const SizedBox(height: 24),
                    _buildCommunicationSection(),
                    const SizedBox(height: 24),
                    _buildDataSection(),

                    const SizedBox(height: 24),

                    // Privacy review section
                    _buildPrivacyReviewSection(variant),

                    const SizedBox(height: 24),

                    // Personalized tip
                    _buildPersonalizedTip(variant),

                    const SizedBox(height: 24),

                    // Complete button
                    _buildCompleteButton(variant),

                    const SizedBox(height: 16),

                    // Progress indicator
                    _buildProgressIndicator(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(String variant) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final heroColor = isDarkMode
        ? const Color(0xFF4A148C)
        : const Color(0xFFE0C7FF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = isDarkMode
        ? Colors.white.withOpacity(0.85)
        : Colors.black.withOpacity(0.7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: heroColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.lock, size: 56, color: textColor),
          const SizedBox(height: 16),
          Text(
            variant == 'gamified'
                ? '🔒 Secure Your Privacy'
                : 'Privacy & Data Settings',
            style: textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            variant == 'gamified'
                ? 'Control your privacy to earn trust badges and security points!'
                : 'Choose how your information is shared and stored. You can change these settings anytime.',
            style: textTheme.bodyLarge?.copyWith(color: subtextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go(RoutePaths.onboardingPreferences),
            icon: Icon(
              Icons.arrow_back,
              color: DesignSystem.colors.textPrimary,
            ),
          ),

          const Spacer(),

          TextButton(
            onPressed: () => _skipStep(),
            child: Text(
              'Skip',
              style: TextStyle(color: DesignSystem.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String variant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          variant == 'gamified'
              ? '🔒 Secure Your Privacy'
              : 'Privacy & Data Settings',
          style: DesignSystem.typography.headlineMedium.copyWith(
            color: DesignSystem.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          variant == 'gamified'
              ? 'Control your privacy to earn trust badges and security points!'
              : 'Choose how your information is shared and stored. You can change these settings anytime.',
          style: DesignSystem.typography.bodyLarge.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileVisibilitySection() {
    return _buildSection(
      title: 'Profile Visibility',
      icon: Icons.visibility,
      children: [
        _buildDropdownSetting(
          title: 'Who can see your profile?',
          value: _profileVisibility,
          items: {
            'public': 'Everyone (Recommended)',
            'players_only': 'Verified players only',
            'connections': 'My connections only',
            'private': 'No one',
          },
          onChanged: (value) {
            setState(() {
              _profileVisibility = value!;
            });
          },
        ),

        const SizedBox(height: 16),

        _buildSwitchSetting(
          title: 'Show real name',
          subtitle: 'Display your full name instead of username',
          value: _showRealName,
          onChanged: (value) {
            setState(() {
              _showRealName = value;
            });
          },
        ),

        _buildSwitchSetting(
          title: 'Show age',
          subtitle: 'Display your age on profile',
          value: _showAge,
          onChanged: (value) {
            setState(() {
              _showAge = value;
            });
          },
        ),

        _buildSwitchSetting(
          title: 'Show general location',
          subtitle: 'Display your city/area to help find local games',
          value: _showLocation,
          onChanged: (value) {
            setState(() {
              _showLocation = value;
            });
          },
        ),

        _buildSwitchSetting(
          title: 'Show sports history',
          subtitle: 'Display past games and statistics',
          value: _showSportsHistory,
          onChanged: (value) {
            setState(() {
              _showSportsHistory = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCommunicationSection() {
    return _buildSection(
      title: 'Communication',
      icon: Icons.chat_bubble_outline,
      children: [
        _buildSwitchSetting(
          title: 'Allow direct messages',
          subtitle: 'Other players can send you messages',
          value: _allowMessages,
          onChanged: (value) {
            setState(() {
              _allowMessages = value;
            });
          },
        ),

        _buildSwitchSetting(
          title: 'Allow game invitations',
          subtitle: 'Receive invites to join games',
          value: _allowGameInvites,
          onChanged: (value) {
            setState(() {
              _allowGameInvites = value;
            });
          },
        ),

        _buildSwitchSetting(
          title: 'Show online status',
          subtitle: 'Let others see when you\'re active',
          value: _showOnlineStatus,
          onChanged: (value) {
            setState(() {
              _showOnlineStatus = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDataSection() {
    return _buildSection(
      title: 'Data & Analytics',
      icon: Icons.storage,
      children: [
        _buildDropdownSetting(
          title: 'Data retention period',
          subtitle: 'How long we keep your inactive data',
          value: _dataRetention,
          items: {
            '6_months': '6 months',
            '1_year': '1 year (Recommended)',
            '2_years': '2 years',
            'indefinite': 'Until I delete my account',
          },
          onChanged: (value) {
            setState(() {
              _dataRetention = value!;
            });
          },
        ),

        const SizedBox(height: 16),

        _buildSwitchSetting(
          title: 'Analytics & performance',
          subtitle: 'Help us improve the app with anonymous usage data',
          value: _allowAnalytics,
          onChanged: (value) {
            setState(() {
              _allowAnalytics = value;
            });
          },
        ),

        _buildSwitchSetting(
          title: 'Marketing communications',
          subtitle: 'Receive emails about new features and games',
          value: _marketingEmails,
          onChanged: (value) {
            setState(() {
              _marketingEmails = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
          Row(
            children: [
              Icon(icon, color: DesignSystem.colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: DesignSystem.typography.titleMedium.copyWith(
                  color: DesignSystem.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DesignSystem.typography.titleSmall.copyWith(
                    color: DesignSystem.colors.textPrimary,
                  ),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: DesignSystem.colors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    String? subtitle,
    required String value,
    required Map<String, String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: DesignSystem.typography.titleSmall.copyWith(
            color: DesignSystem.colors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: DesignSystem.typography.bodySmall.copyWith(
              color: DesignSystem.colors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: DesignSystem.colors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          items: items.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: DesignSystem.typography.bodyMedium,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPrivacyReviewSection(String variant) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignSystem.colors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignSystem.colors.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user,
                color: DesignSystem.colors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Privacy Review Complete',
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
            'I have reviewed and understand my privacy settings. I can update these preferences anytime in my account settings.',
            style: DesignSystem.typography.bodyMedium.copyWith(
              color: DesignSystem.colors.primary,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Checkbox(
                value: _hasReviewedPrivacy,
                onChanged: (value) {
                  setState(() {
                    _hasReviewedPrivacy = value ?? false;
                  });
                },
                activeColor: DesignSystem.colors.primary,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _hasReviewedPrivacy = !_hasReviewedPrivacy;
                    });
                  },
                  child: Text(
                    'I confirm I have reviewed my privacy settings',
                    style: DesignSystem.typography.bodyMedium.copyWith(
                      color: DesignSystem.colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (variant == 'gamified' && _hasReviewedPrivacy)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: DesignSystem.colors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.military_tech,
                    color: DesignSystem.colors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Privacy Champion badge earned!',
                    style: DesignSystem.typography.bodySmall.copyWith(
                      color: DesignSystem.colors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalizedTip(String variant) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignSystem.colors.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignSystem.colors.info.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: DesignSystem.colors.info, size: 20),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              'Your privacy settings can be updated anytime. We recommend keeping your profile visible to find the best game matches.',
              style: DesignSystem.typography.bodyMedium.copyWith(
                color: DesignSystem.colors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton(String variant) {
    final canComplete = _hasReviewedPrivacy;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canComplete ? () => _completeOnboarding() : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignSystem.colors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canComplete ? 4 : 0,
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
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    variant == 'gamified'
                        ? '🎉 Complete & Claim All Rewards!'
                        : '✨ Complete Profile',
                    style: DesignSystem.typography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Icon(Icons.check, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Text(
          'Step 4 of 4',
          style: DesignSystem.typography.bodySmall.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
        ),

        const SizedBox(height: 8),

        LinearProgressIndicator(
          value: 1.0,
          backgroundColor: DesignSystem.colors.border,
          valueColor: AlwaysStoppedAnimation<Color>(
            DesignSystem.colors.primary,
          ),
        ),
      ],
    );
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final controller = ref.read(onboardingControllerProvider);
      final gamification = ref.read(onboardingGamificationProvider);
      final variant = controller.currentVariant ?? 'control';

      // Prepare step data
      final stepData = {
        'profile_visibility': _profileVisibility,
        'show_real_name': _showRealName,
        'show_age': _showAge,
        'show_location': _showLocation,
        'show_sports_history': _showSportsHistory,
        'allow_messages': _allowMessages,
        'allow_game_invites': _allowGameInvites,
        'show_online_status': _showOnlineStatus,
        'data_retention': _dataRetention,
        'allow_analytics': _allowAnalytics,
        'marketing_emails': _marketingEmails,
        'privacy_reviewed': _hasReviewedPrivacy,
        'completed_at': DateTime.now().toIso8601String(),
      };

      // Complete the step
      await controller.completeStep(4, stepData);

      // Award points for gamified variant
      if (variant == 'gamified') {
        final userId = controller.currentUserId;
        if (userId != null) {
          int points = 20; // Base completion points
          if (_hasReviewedPrivacy) points += 10; // Privacy review bonus

          await gamification.awardPoints(
            userId,
            points,
            'onboarding_step_4',
            'Completed privacy settings',
          );
        }
      }

      // Complete entire onboarding
      await controller.completeOnboarding();

      // Navigate to completion screen
      context.go(RoutePaths.onboardingCompletion);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing onboarding: $e'),
          backgroundColor: DesignSystem.colors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _skipStep() {
    final controller = ref.read(onboardingControllerProvider);
    controller.skipStep(4, reason: 'user_skipped');
    context.go(RoutePaths.onboardingCompletion);
  }
}
