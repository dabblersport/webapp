import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'onboarding_welcome_screen.dart';
import 'package:dabbler/themes/design_system.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

class OnboardingSportsScreen extends ConsumerStatefulWidget {
  const OnboardingSportsScreen({super.key});

  @override
  ConsumerState<OnboardingSportsScreen> createState() =>
      _OnboardingSportsScreenState();
}

class _OnboardingSportsScreenState extends ConsumerState<OnboardingSportsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Set<String> _selectedSports = {};
  final Map<String, int> _skillLevels = {};
  final Set<String> _interestedSports = {};
  bool _isLoading = false;

  // Available sports with categories
  final Map<String, List<Sport>> _sportsByCategory = {
    'Popular': [
      Sport(
        id: 'football',
        name: 'Football',
        icon: '⚽',
        description: 'The beautiful game',
      ),
      Sport(
        id: 'basketball',
        name: 'Basketball',
        icon: '🏀',
        description: 'Fast-paced court action',
      ),
      Sport(
        id: 'tennis',
        name: 'Tennis',
        icon: '🎾',
        description: 'Classic racket sport',
      ),
      Sport(
        id: 'badminton',
        name: 'Badminton',
        icon: '🏸',
        description: 'Quick reflexes required',
      ),
    ],
    'Team Sports': [
      Sport(
        id: 'volleyball',
        name: 'Volleyball',
        icon: '🏐',
        description: 'Beach or court',
      ),
      Sport(
        id: 'rugby',
        name: 'Rugby',
        icon: '🏉',
        description: 'Contact team sport',
      ),
      Sport(
        id: 'hockey',
        name: 'Hockey',
        icon: '🏒',
        description: 'Field or ice hockey',
      ),
      Sport(
        id: 'cricket',
        name: 'Cricket',
        icon: '🏏',
        description: 'Bat and ball game',
      ),
    ],
    'Individual': [
      Sport(
        id: 'running',
        name: 'Running',
        icon: '🏃',
        description: 'Solo or group runs',
      ),
      Sport(
        id: 'swimming',
        name: 'Swimming',
        icon: '🏊',
        description: 'Pool or open water',
      ),
      Sport(
        id: 'cycling',
        name: 'Cycling',
        icon: '🚴',
        description: 'Road or mountain',
      ),
      Sport(
        id: 'golf',
        name: 'Golf',
        icon: '⛳',
        description: 'Precision and patience',
      ),
    ],
    'Fitness': [
      Sport(
        id: 'yoga',
        name: 'Yoga',
        icon: '🧘',
        description: 'Mind-body wellness',
      ),
      Sport(
        id: 'gym',
        name: 'Gym Training',
        icon: '💪',
        description: 'Strength and conditioning',
      ),
      Sport(
        id: 'crossfit',
        name: 'CrossFit',
        icon: '🏋️',
        description: 'High-intensity workouts',
      ),
      Sport(
        id: 'martial_arts',
        name: 'Martial Arts',
        icon: '🥋',
        description: 'Discipline and technique',
      ),
    ],
  };

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
    final existingData = controller.progress?.stepData['step_2'];

    if (existingData != null) {
      final sports = List<String>.from(existingData['sports'] ?? []);
      _selectedSports.addAll(sports);

      final skills = Map<String, int>.from(existingData['skill_levels'] ?? {});
      _skillLevels.addAll(skills);

      final interested = List<String>.from(
        existingData['interested_sports'] ?? [],
      );
      _interestedSports.addAll(interested);
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
          onPressed: () => context.go(RoutePaths.onboardingBasicInfo),
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
                    // Sports categories
                    ..._sportsByCategory.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildSportsCategory(
                          entry.key,
                          entry.value,
                          variant,
                        ),
                      );
                    }),

                    // Skill levels section
                    if (_selectedSports.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSkillLevels(variant),
                    ],

                    // Want to try section
                    const SizedBox(height: 16),
                    _buildWantToTry(variant),

                    const SizedBox(height: 24),

                    // Personalized tip
                    _buildPersonalizedTip(variant),

                    const SizedBox(height: 24),

                    // Continue button
                    _buildContinueButton(variant),

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
          Text('🏆', style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            variant == 'gamified'
                ? '🏆 Choose Your Sports Arena'
                : 'What Sports Do You Play?',
            style: textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            variant == 'gamified'
                ? 'Each sport unlocks new game opportunities and rewards!'
                : 'Select the sports you enjoy playing so we can find perfect matches',
            style: textTheme.bodyLarge?.copyWith(color: subtextColor),
            textAlign: TextAlign.center,
          ),
          if (variant == 'gamified' && _selectedSports.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_selectedSports.length * 5} points earned from sports!',
                  style: textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
            onPressed: () => context.go(RoutePaths.onboardingBasicInfo),
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
              ? '🏆 Choose Your Sports Arena'
              : 'What Sports Do You Play?',
          style: DesignSystem.typography.headlineMedium.copyWith(
            color: DesignSystem.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          variant == 'gamified'
              ? 'Each sport unlocks new game opportunities and rewards!'
              : 'Select the sports you enjoy playing so we can find perfect matches',
          style: DesignSystem.typography.bodyLarge.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
        ),

        if (variant == 'gamified' && _selectedSports.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: DesignSystem.colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_selectedSports.length * 5} points earned from sports!',
              style: DesignSystem.typography.bodySmall.copyWith(
                color: DesignSystem.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSportsCategory(
    String category,
    List<Sport> sports,
    String variant,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: DesignSystem.typography.titleMedium.copyWith(
            color: DesignSystem.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sports
              .map((sport) => _buildSportChip(sport, variant))
              .toList(),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSportChip(Sport sport, String variant) {
    final isSelected = _selectedSports.contains(sport.id);
    final isInterested = _interestedSports.contains(sport.id);

    return GestureDetector(
      onTap: () => _toggleSport(sport.id),
      onLongPress: () => _showSportDetails(sport),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignSystem.colors.primary
              : isInterested
              ? DesignSystem.colors.secondary.withOpacity(0.1)
              : DesignSystem.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? DesignSystem.colors.primary
                : isInterested
                ? DesignSystem.colors.secondary
                : DesignSystem.colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sport.icon, style: const TextStyle(fontSize: 18)),

            const SizedBox(width: 8),

            Text(
              sport.name,
              style: DesignSystem.typography.bodyMedium.copyWith(
                color: isSelected
                    ? Colors.white
                    : DesignSystem.colors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),

            if (variant == 'gamified' && isSelected)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+5',
                  style: DesignSystem.typography.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillLevels(String variant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          variant == 'gamified'
              ? '💪 Rate Your Skills (Bonus Points!)'
              : 'Rate Your Skill Level',
          style: DesignSystem.typography.titleMedium.copyWith(
            color: DesignSystem.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'This helps us match you with players of similar ability',
          style: DesignSystem.typography.bodyMedium.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
        ),

        const SizedBox(height: 16),

        ..._selectedSports.map((sportId) {
          final sport = _findSportById(sportId);
          return sport != null
              ? _buildSkillSlider(sport, variant)
              : const SizedBox.shrink();
        }),
      ],
    );
  }

  Widget _buildSkillSlider(Sport sport, String variant) {
    final skillLevel = _skillLevels[sport.id] ?? 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignSystem.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignSystem.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(sport.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                sport.name,
                style: DesignSystem.typography.titleSmall.copyWith(
                  color: DesignSystem.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _getSkillLevelText(skillLevel),
                style: DesignSystem.typography.bodySmall.copyWith(
                  color: DesignSystem.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: DesignSystem.colors.primary,
              inactiveTrackColor: DesignSystem.colors.border,
              thumbColor: DesignSystem.colors.primary,
              overlayColor: DesignSystem.colors.primary.withOpacity(0.2),
            ),
            child: Slider(
              value: skillLevel.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (value) {
                setState(() {
                  _skillLevels[sport.id] = value.round();
                });
              },
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Beginner',
                style: DesignSystem.typography.bodySmall.copyWith(
                  color: DesignSystem.colors.textSecondary,
                ),
              ),
              Text(
                'Expert',
                style: DesignSystem.typography.bodySmall.copyWith(
                  color: DesignSystem.colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWantToTry(String variant) {
    final allSports = _sportsByCategory.values
        .expand((sports) => sports)
        .toList();
    final availableToTry = allSports
        .where((sport) => !_selectedSports.contains(sport.id))
        .toList();

    if (availableToTry.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          variant == 'gamified'
              ? '🌟 Sports You Want to Try'
              : 'Interested in Trying?',
          style: DesignSystem.typography.titleMedium.copyWith(
            color: DesignSystem.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'We\'ll show you beginner-friendly games for these sports',
          style: DesignSystem.typography.bodyMedium.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
        ),

        const SizedBox(height: 16),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableToTry
              .take(8)
              .map((sport) => _buildInterestedChip(sport, variant))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildInterestedChip(Sport sport, String variant) {
    final isInterested = _interestedSports.contains(sport.id);

    return GestureDetector(
      onTap: () => _toggleInterested(sport.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isInterested
              ? DesignSystem.colors.secondary.withOpacity(0.1)
              : DesignSystem.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isInterested
                ? DesignSystem.colors.secondary
                : DesignSystem.colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sport.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              sport.name,
              style: DesignSystem.typography.bodySmall.copyWith(
                color: isInterested
                    ? DesignSystem.colors.secondary
                    : DesignSystem.colors.textSecondary,
                fontWeight: isInterested ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalizedTip(String variant) {
    final controller = ref.read(onboardingControllerProvider);
    final tip = controller.getPersonalizedTip();

    if (tip.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignSystem.colors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignSystem.colors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: DesignSystem.colors.primary,
            size: 20,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              tip,
              style: DesignSystem.typography.bodyMedium.copyWith(
                color: DesignSystem.colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(String variant) {
    final canContinue = _selectedSports.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canContinue ? () => _continue() : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignSystem.colors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canContinue ? 4 : 0,
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
                        ? 'Collect Points & Continue'
                        : 'Continue',
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
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Text(
          'Step 2 of 4',
          style: DesignSystem.typography.bodySmall.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
        ),

        const SizedBox(height: 8),

        LinearProgressIndicator(
          value: 0.5,
          backgroundColor: DesignSystem.colors.border,
          valueColor: AlwaysStoppedAnimation<Color>(
            DesignSystem.colors.primary,
          ),
        ),
      ],
    );
  }

  void _toggleSport(String sportId) {
    setState(() {
      if (_selectedSports.contains(sportId)) {
        _selectedSports.remove(sportId);
        _skillLevels.remove(sportId);
      } else {
        _selectedSports.add(sportId);
        _skillLevels[sportId] = 3; // Default skill level
      }

      // Remove from interested if selected
      if (_selectedSports.contains(sportId)) {
        _interestedSports.remove(sportId);
      }
    });
  }

  void _toggleInterested(String sportId) {
    setState(() {
      if (_interestedSports.contains(sportId)) {
        _interestedSports.remove(sportId);
      } else {
        _interestedSports.add(sportId);
      }
    });
  }

  Sport? _findSportById(String id) {
    for (final sports in _sportsByCategory.values) {
      for (final sport in sports) {
        if (sport.id == id) return sport;
      }
    }
    return null;
  }

  String _getSkillLevelText(int level) {
    switch (level) {
      case 1:
        return 'Beginner';
      case 2:
        return 'Casual';
      case 3:
        return 'Intermediate';
      case 4:
        return 'Advanced';
      case 5:
        return 'Expert';
      default:
        return 'Intermediate';
    }
  }

  void _showSportDetails(Sport sport) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DesignSystem.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            Text(sport.icon, style: const TextStyle(fontSize: 40)),

            const SizedBox(height: 12),

            Text(
              sport.name,
              style: DesignSystem.typography.headlineSmall.copyWith(
                color: DesignSystem.colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              sport.description,
              style: DesignSystem.typography.bodyMedium.copyWith(
                color: DesignSystem.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _toggleSport(sport.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedSports.contains(sport.id)
                      ? DesignSystem.colors.error
                      : DesignSystem.colors.primary,
                ),
                child: Text(
                  _selectedSports.contains(sport.id)
                      ? 'Remove'
                      : 'Add to My Sports',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continue() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final controller = ref.read(onboardingControllerProvider);
      final gamification = ref.read(onboardingGamificationProvider);
      final variant = controller.currentVariant ?? 'control';

      // Prepare step data
      final stepData = {
        'sports': _selectedSports.toList(),
        'skill_levels': _skillLevels,
        'interested_sports': _interestedSports.toList(),
        'completed_at': DateTime.now().toIso8601String(),
      };

      // Complete the step
      await controller.completeStep(2, stepData);

      // Award points for gamified variant
      if (variant == 'gamified') {
        final userId = controller.currentUserId;
        if (userId != null) {
          int points = _selectedSports.length * 5; // 5 points per sport
          if (_skillLevels.isNotEmpty) points += 15; // Skill level bonus
          if (_interestedSports.isNotEmpty) points += 5; // Interest bonus

          await gamification.awardPoints(
            userId,
            points,
            'onboarding_step_2',
            'Completed sports preferences',
          );
        }
      }

      // Show achievement if gamified
      if (variant == 'gamified') {
        _showAchievement();
      } else {
        _navigateNext();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving sports preferences: $e'),
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
    controller.skipStep(2, reason: 'user_skipped');
    context.go(RoutePaths.onboardingPreferences);
  }

  void _showAchievement() {
    final gamification = ref.read(onboardingGamificationProvider);
    final achievement = gamification.getStepAchievement(2, 'gamified');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DesignSystem.colors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events,
                size: 40,
                color: DesignSystem.colors.success,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              achievement.title,
              style: DesignSystem.typography.headlineSmall.copyWith(
                color: DesignSystem.colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              achievement.description,
              style: DesignSystem.typography.bodyMedium.copyWith(
                color: DesignSystem.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignSystem.colors.primary,
              ),
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateNext() {
    context.go(RoutePaths.onboardingPreferences);
  }
}

class Sport {
  final String id;
  final String name;
  final String icon;
  final String description;

  Sport({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });
}
