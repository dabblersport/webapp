import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../themes/design_system.dart';
import '../../../../../utils/constants/route_constants.dart';
import 'onboarding_welcome_screen.dart'; // For providers

class OnboardingPreferencesScreen extends ConsumerStatefulWidget {
  const OnboardingPreferencesScreen({super.key});

  @override
  ConsumerState<OnboardingPreferencesScreen> createState() =>
      _OnboardingPreferencesScreenState();
}

class _OnboardingPreferencesScreenState
    extends ConsumerState<OnboardingPreferencesScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Location preferences
  String? _selectedCity;
  double _maxDistance = 10.0; // km
  final Set<String> _preferredAreas = {};

  // Availability preferences
  final Set<String> _availableDays = {};
  TimeOfDay? _preferredStartTime;
  TimeOfDay? _preferredEndTime;
  final Set<String> _preferredDurations = {};

  // Game preferences
  String _gameSize = 'any';
  String _skillMatch = 'similar';
  bool _openToMeetNewPeople = true;
  bool _preferRegularGames = false;

  bool _isLoading = false;

  // Mock data - replace with real data
  final List<String> _cities = [
    'London',
    'Manchester',
    'Birmingham',
    'Bristol',
    'Leeds',
  ];
  final Map<String, List<String>> _areasByCity = {
    'London': ['Central', 'North', 'South', 'East', 'West'],
    'Manchester': [
      'City Centre',
      'Northern Quarter',
      'Didsbury',
      'Chorlton',
      'Sale',
    ],
    'Birmingham': [
      'City Centre',
      'Edgbaston',
      'Moseley',
      'Harborne',
      'Solihull',
    ],
    'Bristol': ['City Centre', 'Clifton', 'Redland', 'Southville', 'Easton'],
    'Leeds': [
      'City Centre',
      'Headingley',
      'Chapel Allerton',
      'Roundhay',
      'Horsforth',
    ],
  };

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final List<String> _durations = [
    '30 mins',
    '1 hour',
    '1.5 hours',
    '2+ hours',
  ];

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
    final existingData = controller.progress?.stepData['step_3'];

    if (existingData != null) {
      _selectedCity = existingData['city'];
      _maxDistance = (existingData['max_distance'] ?? 10.0).toDouble();
      _preferredAreas.addAll(
        List<String>.from(existingData['preferred_areas'] ?? []),
      );

      _availableDays.addAll(
        List<String>.from(existingData['available_days'] ?? []),
      );
      if (existingData['preferred_start_time'] != null) {
        final time = existingData['preferred_start_time'].split(':');
        _preferredStartTime = TimeOfDay(
          hour: int.parse(time[0]),
          minute: int.parse(time[1]),
        );
      }
      if (existingData['preferred_end_time'] != null) {
        final time = existingData['preferred_end_time'].split(':');
        _preferredEndTime = TimeOfDay(
          hour: int.parse(time[0]),
          minute: int.parse(time[1]),
        );
      }
      _preferredDurations.addAll(
        List<String>.from(existingData['preferred_durations'] ?? []),
      );

      _gameSize = existingData['game_size'] ?? 'any';
      _skillMatch = existingData['skill_match'] ?? 'similar';
      _openToMeetNewPeople = existingData['open_to_meet_new_people'] ?? true;
      _preferRegularGames = existingData['prefer_regular_games'] ?? false;
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
    return Column(
      children: [
        // App bar
        _buildAppBar(),

        // Content
        Expanded(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildHeader(variant),
                ),
              ),

              // Location section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildLocationSection(variant),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Availability section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildAvailabilitySection(variant),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Game preferences section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildGamePreferencesSection(variant),
                ),
              ),

              // Bottom section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      // Personalized tip
                      _buildPersonalizedTip(variant),

                      const SizedBox(height: 24),

                      // Continue button
                      _buildContinueButton(variant),

                      const SizedBox(height: 16),

                      // Progress indicator
                      _buildProgressIndicator(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go(RoutePaths.onboardingSports),
            icon: Icon(
              LucideIcons.arrowLeft,
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
              ? '📍 Set Your Game Zone'
              : 'Where & When Do You Play?',
          style: DesignSystem.typography.headlineMedium.copyWith(
            color: DesignSystem.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          variant == 'gamified'
              ? 'Optimize your preferences to unlock location rewards!'
              : 'Help us recommend games that fit your schedule and location',
          style: DesignSystem.typography.bodyLarge.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection(String variant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.mapPin,
              color: DesignSystem.colors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Location Preferences',
              style: DesignSystem.typography.titleMedium.copyWith(
                color: DesignSystem.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // City selection
        DropdownButtonFormField<String>(
          initialValue: _selectedCity,
          decoration: InputDecoration(
            labelText: 'Primary City',
            prefixIcon: const Icon(LucideIcons.mapPin),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: _cities
              .map((city) => DropdownMenuItem(value: city, child: Text(city)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedCity = value;
              _preferredAreas.clear(); // Clear areas when city changes
            });
          },
        ),

        const SizedBox(height: 16),

        // Distance slider
        Text(
          'Maximum Distance: ${_maxDistance.round()} km',
          style: DesignSystem.typography.titleSmall.copyWith(
            color: DesignSystem.colors.textPrimary,
          ),
        ),

        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: DesignSystem.colors.primary,
            inactiveTrackColor: DesignSystem.colors.border,
            thumbColor: DesignSystem.colors.primary,
          ),
          child: Slider(
            value: _maxDistance,
            min: 1,
            max: 50,
            divisions: 49,
            onChanged: (value) {
              setState(() {
                _maxDistance = value;
              });
            },
          ),
        ),

        // Preferred areas
        if (_selectedCity != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Preferred Areas (Optional)',
                style: DesignSystem.typography.titleSmall.copyWith(
                  color: DesignSystem.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _areasByCity[_selectedCity!]!
                    .map((area) => _buildAreaChip(area))
                    .toList(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAreaChip(String area) {
    final isSelected = _preferredAreas.contains(area);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _preferredAreas.remove(area);
          } else {
            _preferredAreas.add(area);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignSystem.colors.primary.withOpacity(0.1)
              : DesignSystem.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? DesignSystem.colors.primary
                : DesignSystem.colors.border,
          ),
        ),
        child: Text(
          area,
          style: DesignSystem.typography.bodySmall.copyWith(
            color: isSelected
                ? DesignSystem.colors.primary
                : DesignSystem.colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilitySection(String variant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.calendar,
              color: DesignSystem.colors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Availability',
              style: DesignSystem.typography.titleMedium.copyWith(
                color: DesignSystem.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Available days
        Text(
          'Available Days',
          style: DesignSystem.typography.titleSmall.copyWith(
            color: DesignSystem.colors.textPrimary,
          ),
        ),

        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _days.map((day) => _buildDayChip(day)).toList(),
        ),

        const SizedBox(height: 20),

        // Preferred times
        Row(
          children: [
            Expanded(
              child: _buildTimeSelector(
                label: 'Earliest Start',
                time: _preferredStartTime,
                onTimeSelected: (time) {
                  setState(() {
                    _preferredStartTime = time;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimeSelector(
                label: 'Latest Finish',
                time: _preferredEndTime,
                onTimeSelected: (time) {
                  setState(() {
                    _preferredEndTime = time;
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Preferred durations
        Text(
          'Preferred Game Duration',
          style: DesignSystem.typography.titleSmall.copyWith(
            color: DesignSystem.colors.textPrimary,
          ),
        ),

        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _durations
              .map((duration) => _buildDurationChip(duration))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDayChip(String day) {
    final isSelected = _availableDays.contains(day);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _availableDays.remove(day);
          } else {
            _availableDays.add(day);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignSystem.colors.primary
              : DesignSystem.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? DesignSystem.colors.primary
                : DesignSystem.colors.border,
          ),
        ),
        child: Text(
          day.substring(0, 3), // Show first 3 letters
          style: DesignSystem.typography.bodySmall.copyWith(
            color: isSelected
                ? Colors.white
                : DesignSystem.colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelector({
    required String label,
    TimeOfDay? time,
    required Function(TimeOfDay) onTimeSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        final selectedTime = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 18, minute: 0),
        );
        if (selectedTime != null) {
          onTimeSelected(selectedTime);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: DesignSystem.colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: DesignSystem.typography.bodySmall.copyWith(
                color: DesignSystem.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time?.format(context) ?? 'Select time',
              style: DesignSystem.typography.titleSmall.copyWith(
                color: time != null
                    ? DesignSystem.colors.textPrimary
                    : DesignSystem.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChip(String duration) {
    final isSelected = _preferredDurations.contains(duration);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _preferredDurations.remove(duration);
          } else {
            _preferredDurations.add(duration);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignSystem.colors.primary.withOpacity(0.1)
              : DesignSystem.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? DesignSystem.colors.primary
                : DesignSystem.colors.border,
          ),
        ),
        child: Text(
          duration,
          style: DesignSystem.typography.bodySmall.copyWith(
            color: isSelected
                ? DesignSystem.colors.primary
                : DesignSystem.colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildGamePreferencesSection(String variant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.settings,
              color: DesignSystem.colors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Game Preferences',
              style: DesignSystem.typography.titleMedium.copyWith(
                color: DesignSystem.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Game size preference
        _buildPreferenceDropdown(
          label: 'Preferred Game Size',
          value: _gameSize,
          items: [
            'Any Size',
            'Small Groups (2-5 players)',
            'Medium Groups (6-10 players)',
            'Large Groups (11+ players)',
          ],
          onChanged: (value) {
            setState(() {
              _gameSize = value!;
            });
          },
        ),

        const SizedBox(height: 16),

        // Skill matching preference
        _buildPreferenceDropdown(
          label: 'Skill Level Matching',
          value: _skillMatch,
          items: [
            'Similar skill level',
            'Mixed skill levels',
            'Play with better players',
            'Help beginners',
          ],
          onChanged: (value) {
            setState(() {
              _skillMatch = value!;
            });
          },
        ),

        const SizedBox(height: 20),

        // Social preferences
        _buildSwitchTile(
          title: 'Open to meeting new people',
          subtitle: 'Show me games with players I haven\'t met',
          value: _openToMeetNewPeople,
          onChanged: (value) {
            setState(() {
              _openToMeetNewPeople = value;
            });
          },
        ),

        const SizedBox(height: 12),

        _buildSwitchTile(
          title: 'Prefer regular games',
          subtitle: 'Prioritize recurring weekly/monthly games',
          value: _preferRegularGames,
          onChanged: (value) {
            setState(() {
              _preferRegularGames = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPreferenceDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: DesignSystem.typography.titleSmall.copyWith(
            color: DesignSystem.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignSystem.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignSystem.colors.border),
      ),
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
            LucideIcons.lightbulb,
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
    final canContinue = _selectedCity != null || _availableDays.isNotEmpty;

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
                        ? 'Unlock Location Rewards!'
                        : 'Continue',
                    style: DesignSystem.typography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Icon(LucideIcons.arrowRight, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Text(
          'Step 3 of 4',
          style: DesignSystem.typography.bodySmall.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
        ),

        const SizedBox(height: 8),

        LinearProgressIndicator(
          value: 0.75,
          backgroundColor: DesignSystem.colors.border,
          valueColor: AlwaysStoppedAnimation<Color>(
            DesignSystem.colors.primary,
          ),
        ),
      ],
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
        'city': _selectedCity,
        'max_distance': _maxDistance,
        'preferred_areas': _preferredAreas.toList(),
        'available_days': _availableDays.toList(),
        'preferred_start_time': _preferredStartTime?.format(context),
        'preferred_end_time': _preferredEndTime?.format(context),
        'preferred_durations': _preferredDurations.toList(),
        'game_size': _gameSize,
        'skill_match': _skillMatch,
        'open_to_meet_new_people': _openToMeetNewPeople,
        'prefer_regular_games': _preferRegularGames,
        'completed_at': DateTime.now().toIso8601String(),
      };

      // Complete the step
      await controller.completeStep(3, stepData);

      // Award points for gamified variant
      if (variant == 'gamified') {
        final userId = controller.currentUserId;
        if (userId != null) {
          int points = 15; // Base points
          if (_selectedCity != null) points += 5;
          if (_availableDays.isNotEmpty) points += 5;
          if (_preferredAreas.isNotEmpty) points += 5;

          await gamification.awardPoints(
            userId,
            points,
            'onboarding_step_3',
            'Completed preferences setup',
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
          content: Text('Error saving preferences: $e'),
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
    controller.skipStep(3, reason: 'user_skipped');
    context.go(RoutePaths.onboardingPrivacy);
  }

  void _showAchievement() {
    final gamification = ref.read(onboardingGamificationProvider);
    final achievement = gamification.getStepAchievement(3, 'gamified');

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
                LucideIcons.mapPin,
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
    context.go(RoutePaths.onboardingPrivacy);
  }
}
