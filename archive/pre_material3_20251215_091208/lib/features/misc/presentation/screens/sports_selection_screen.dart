import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/utils/constants.dart';
import 'package:dabbler/core/utils/helpers.dart';
import 'package:dabbler/widgets/onboarding_progress.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/authentication/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/core/config/feature_flags.dart';

class SportsSelectionScreen extends ConsumerStatefulWidget {
  const SportsSelectionScreen({super.key});

  @override
  ConsumerState<SportsSelectionScreen> createState() =>
      _SportsSelectionScreenState();
}

class _SportsSelectionScreenState extends ConsumerState<SportsSelectionScreen> {
  String? _preferredSport;
  final Set<String> _interests = {};
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadExistingUserData();
  }

  Future<void> _loadExistingUserData() async {
    try {
      // Check if we have onboarding data from previous steps
      final onboardingData = ref.read(onboardingDataProvider);
      if (onboardingData?.preferredSport != null) {
        setState(() {
          _preferredSport = onboardingData?.preferredSport;
          if (onboardingData?.interests != null) {
            _interests.addAll(onboardingData!.interests!);
          }
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

  void _selectPreferredSport(String sport) {
    setState(() {
      _preferredSport = sport;
      // If the sport was in interests, remove it
      _interests.remove(sport);
    });
  }

  void _toggleInterest(String sport) {
    // Don't allow selecting preferred sport as interest
    if (sport == _preferredSport) {
      return;
    }

    setState(() {
      if (_interests.contains(sport)) {
        _interests.remove(sport);
      } else {
        // Limit to 3 interests
        if (_interests.length < 3) {
          _interests.add(sport);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can select up to 3 interests'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_preferredSport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your preferred sport'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save to OnboardingData provider
      ref
          .read(onboardingDataProvider.notifier)
          .setSports(
            preferredSport: _preferredSport!,
            interests: _interests.isNotEmpty ? _interests.toList() : null,
          );

      // Navigate to SetUsername for all users (passwordless flow)
      if (mounted) {
        context.push(RoutePaths.setUsername);
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
          : SingleChildScrollView(
              child: ConstrainedBox(
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
                        const OnboardingProgress(currentStep: 3),
                        SizedBox(height: AppSpacing.xl),
                        // Title
                        Text(
                          'Choose Your Sports',
                          style: AppTypography.headlineMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: AppSpacing.sm),
                        // Subtitle
                        Text(
                          'Select your preferred sport and additional interests',
                          style: AppTypography.bodyLarge.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.9),
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
                        // Preferred Sport Section
                        Row(
                          children: [
                            Text(
                              'Preferred Sport',
                              style: AppTypography.titleLarge.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Required',
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: AppSpacing.xs),

                        Text(
                          'Choose your main sport',
                          style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),

                        SizedBox(height: AppSpacing.md),

                        // Preferred Sport Grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.0,
                              ),
                          itemCount: AppConstants.availableSports
                              .where(
                                (sport) => FeatureFlags.isSportEnabled(sport),
                              )
                              .length,
                          itemBuilder: (context, index) {
                            final enabledSports = AppConstants.availableSports
                                .where(
                                  (sport) => FeatureFlags.isSportEnabled(sport),
                                )
                                .toList();
                            final sport = enabledSports[index];
                            final isSelected = _preferredSport == sport;

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _selectPreferredSport(sport),
                                borderRadius: BorderRadius.circular(12),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.outline,
                                      width: isSelected ? 2 : 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        AppHelpers.getSportIcon(sport),
                                        size: 32,
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        AppHelpers.getSportDisplayName(sport),
                                        style: AppTypography.bodySmall.copyWith(
                                          fontWeight: FontWeight.normal,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(height: 4),
                                        Icon(
                                          Iconsax.tick_circle_copy,
                                          size: 16,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        SizedBox(height: AppSpacing.xxl),

                        // Interests Section
                        Row(
                          children: [
                            Text(
                              'Additional Interests',
                              style: AppTypography.titleLarge.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Optional',
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: AppSpacing.xs),

                        Text(
                          'Select up to 3 additional sports (${_interests.length}/3)',
                          style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),

                        SizedBox(height: AppSpacing.md),

                        // Interests Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: AppConstants.availableSports.map((sport) {
                            final isSelected = _interests.contains(sport);
                            final isPreferred = _preferredSport == sport;
                            final isDisabled =
                                isPreferred ||
                                (_interests.length >= 3 && !isSelected);

                            return Opacity(
                              opacity: isDisabled ? 0.5 : 1.0,
                              child: FilterChip(
                                label: Text(
                                  AppHelpers.getSportDisplayName(sport),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                avatar: Icon(
                                  AppHelpers.getSportIcon(sport),
                                  size: 20,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                                selected: isSelected,
                                showCheckmark: false,
                                onSelected: isDisabled
                                    ? null
                                    : (bool selected) => _toggleInterest(sport),
                                backgroundColor: Colors.transparent,
                                selectedColor: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.2),
                                side: BorderSide(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                                  width: isSelected ? 2 : 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        SizedBox(height: AppSpacing.xl),

                        // Continue Button
                        FilledButton(
                          onPressed: (_isLoading || _preferredSport == null)
                              ? null
                              : _handleSubmit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                          ),
                          child: Text(
                            _isLoading ? 'Continuing...' : 'Continue',
                          ),
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
            ),
    );
  }
}
