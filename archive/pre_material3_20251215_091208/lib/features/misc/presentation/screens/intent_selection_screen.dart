import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/widgets/onboarding_progress.dart';
import 'package:dabbler/features/authentication/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/design_system/design_system.dart';

class IntentSelectionScreen extends ConsumerStatefulWidget {
  const IntentSelectionScreen({super.key});

  @override
  ConsumerState<IntentSelectionScreen> createState() =>
      _IntentSelectionScreenState();
}

class _IntentSelectionScreenState extends ConsumerState<IntentSelectionScreen> {
  String? _selectedIntent;
  bool _isLoading = false;
  bool _isLoadingData = true;

  // MVP: Filter intentions based on feature flags
  List<Map<String, String>> get _intentOptions {
    final allOptions = [
      {
        'value': 'organise',
        'title': 'Organise',
        'description': 'List games, manage slots, and host matches',
        'icon': 'calendar',
      },
      {
        'value': 'compete',
        'title': 'Compete',
        'description': 'Serious matches, rankings, and tournaments',
        'icon': 'trophy',
      },
      {
        'value': 'social',
        'title': 'Social',
        'description': 'Casual play, meet people, and have fun',
        'icon': 'people',
      },
    ];

    // MVP: Hide organise option if organiser profile is disabled
    if (!FeatureFlags.enableOrganiserProfile) {
      return allOptions.where((opt) => opt['value'] != 'organise').toList();
    }

    return allOptions;
  }

  @override
  void initState() {
    super.initState();
    _loadExistingUserData();
  }

  Future<void> _loadExistingUserData() async {
    try {
      // Check if we have data in onboarding provider
      final onboardingData = ref.read(onboardingDataProvider);
      if (onboardingData?.intention != null &&
          onboardingData!.intention!.isNotEmpty) {
        setState(() {
          _selectedIntent = onboardingData.intention;
        });
      } else {}
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  void _selectIntent(String intent) {
    setState(() {
      _selectedIntent = intent;
    });
  }

  Future<void> _handleSubmit() async {
    if (_selectedIntent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your main goal'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Store intention in onboarding provider
      ref.read(onboardingDataProvider.notifier).setIntention(_selectedIntent!);

      if (mounted) {
        // Navigate to sports selection screen
        context.push(RoutePaths.sportsSelection);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SingleSectionLayout(
      child: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight - topPadding - bottomPadding - 48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Container
                  Column(
                    children: [
                      SizedBox(height: AppSpacing.xl),
                      // Dabbler logo
                      Center(
                        child: SvgPicture.asset(
                          'assets/images/dabbler_logo.svg',
                          width: 80,
                          height: 88,
                          colorFilter: ColorFilter.mode(
                            Theme.of(context).colorScheme.onSurface,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                      // Dabbler text logo
                      Center(
                        child: SvgPicture.asset(
                          'assets/images/dabbler_text_logo.svg',
                          width: 110,
                          height: 21,
                          colorFilter: ColorFilter.mode(
                            Theme.of(context).colorScheme.onSurface,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.lg),
                      // Onboarding Progress
                      const OnboardingProgress(currentStep: 2),
                      SizedBox(height: AppSpacing.xl),
                      // Title
                      Text(
                        'What is your main goal?',
                        style: AppTypography.headlineMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      // Subtitle
                      Text(
                        'Choose how you want to use Dabbler',
                        style: AppTypography.bodyLarge.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Form Container
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Intent Options - Filtered by feature flags
                      ..._intentOptions.map((option) {
                        final isSelected = _selectedIntent == option['value'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectIntent(option['value']!),
                              borderRadius: BorderRadius.circular(12),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline,
                                    width: isSelected ? 2 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getIntentIcon(option['icon']!),
                                      size: 24,
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.7),
                                    ),
                                    SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        option['title']!,
                                        style: AppTypography.bodyLarge.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Iconsax.tick_circle_copy,
                                        size: 20,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      SizedBox(height: AppSpacing.xl),

                      // Continue Button
                      FilledButton(
                        onPressed: (_isLoading || _selectedIntent == null)
                            ? null
                            : _handleSubmit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: Text(_isLoading ? 'Continuing...' : 'Continue'),
                      ),

                      SizedBox(height: AppSpacing.md),

                      // Back Button
                      TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: const Text('Back'),
                      ),

                      SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  IconData _getIntentIcon(String icon) {
    switch (icon) {
      case 'calendar':
        return Iconsax.calendar_1_copy;
      case 'trophy':
        return Iconsax.cup_copy;
      case 'people':
        return Iconsax.people_copy;
      default:
        return Iconsax.activity_copy;
    }
  }
}
