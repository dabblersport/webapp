import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/core/utils/helpers.dart';
import 'package:dabbler/design_system/tokens/main_dark.dart'
    as main_dark_tokens;
import 'package:dabbler/design_system/tokens/main_light.dart'
    as main_light_tokens;
import 'package:dabbler/utils/ui_constants.dart' hide AppSpacing;
import 'package:dabbler/utils/constants/route_constants.dart';

/// Mode for the primary sport selection screen
enum PrimarySportSelectionMode {
  /// Onboarding flow - creates new user profile
  onboarding,

  /// Add persona flow - adds profile to existing user
  addPersona,
}

/// Screen for selecting primary sport during onboarding or add persona flow
///
/// UI + PROVIDER STATE ONLY (NO DATABASE WRITES)
///
/// Purpose: Select ONE sport to represent the user
///
/// Actions performed:
/// 1. Store selected sport in appropriate provider
/// 2. Navigate to username screen
class PrimarySportSelectionScreen extends ConsumerStatefulWidget {
  final PrimarySportSelectionMode mode;

  const PrimarySportSelectionScreen({
    super.key,
    this.mode = PrimarySportSelectionMode.onboarding,
  });

  @override
  ConsumerState<PrimarySportSelectionScreen> createState() =>
      _PrimarySportSelectionScreenState();
}

class _PrimarySportSelectionScreenState
    extends ConsumerState<PrimarySportSelectionScreen> {
  String? _selectedSport;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-select if only one sport is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final interests = _getInterests();
      if (interests.length == 1) {
        setState(() {
          _selectedSport = interests.first;
        });
      }
    });
  }

  /// Get interests from appropriate provider based on mode
  List<String> _getInterests() {
    if (widget.mode == PrimarySportSelectionMode.addPersona) {
      return ref.read(addPersonaDataProvider)?.interests ?? [];
    }
    return ref.read(onboardingDataProvider)?.interests ?? [];
  }

  void _selectSport(String sport) {
    setState(() {
      _selectedSport = sport;
    });
  }

  Future<void> _handleContinue() async {
    if (_selectedSport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your primary sport'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.mode == PrimarySportSelectionMode.addPersona) {
        // ADD PERSONA MODE: Update addPersonaDataProvider
        ref
            .read(addPersonaDataProvider.notifier)
            .setPrimarySport(_selectedSport!);

        if (mounted) {
          context.push(RoutePaths.addPersonaUsername);
        }
      } else {
        // ONBOARDING MODE: Update onboardingDataProvider
        ref
            .read(onboardingDataProvider.notifier)
            .setSports(
              preferredSport: _selectedSport!,
              interests: ref.read(onboardingDataProvider)?.interests,
            );

        if (mounted) {
          context.push(RoutePaths.setUsername);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

    // Get selected sports from appropriate provider based on mode
    final List<String> selectedSports;
    if (widget.mode == PrimarySportSelectionMode.addPersona) {
      selectedSports = ref.watch(addPersonaDataProvider)?.interests ?? [];
    } else {
      selectedSports = ref.watch(onboardingDataProvider)?.interests ?? [];
    }

    // If no sports selected, show error state
    if (selectedSports.isEmpty) {
      return Scaffold(
        backgroundColor: tokens.main.background,
        body: Center(
          child: Text(
            'No sports selected. Please go back.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: tokens.main.onBackground,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: tokens.main.background,
      body: Padding(
        padding: EdgeInsets.all(AppSpacing.xs),
        child: ClipRRect(
          borderRadius: AppRadius.extraExtraLarge,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tokens.main.secondaryContainer),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpacing.xxxl * 2),
                            // Flow indicator for add persona mode
                            if (widget.mode ==
                                PrimarySportSelectionMode.addPersona)
                              _buildFlowIndicator(theme, tokens),

                            // Title
                            Text(
                              'Choose your primary sport',
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: tokens.main.onSecondaryContainer,
                              ),
                            ),

                            SizedBox(height: AppSpacing.lg),

                            // Subtitle
                            Text(
                              'This sport will appear on your profile and be used by default.',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: tokens.main.onSecondaryContainer,
                              ),
                            ),

                            SizedBox(height: AppSpacing.md),

                            // Helper text
                            Text(
                              'You can change it later.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: tokens.main.onSecondaryContainer
                                    .withOpacity(0.7),
                              ),
                            ),

                            SizedBox(height: AppSpacing.xxl),

                            // Sports List (Radio-style selection)
                            _SportsRadioList(
                              sports: selectedSports,
                              selectedSport: _selectedSport,
                              onSelect: _selectSport,
                              tokens: tokens,
                              theme: theme,
                            ),

                            const Spacer(),

                            // Continue Button
                            FilledButton(
                              onPressed: (_isLoading || _selectedSport == null)
                                  ? null
                                  : _handleContinue,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                shape: const StadiumBorder(),
                                backgroundColor: tokens.main.primary,
                                foregroundColor: tokens.main.onPrimary,
                                textStyle: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Continue'),
                            ),

                            SizedBox(height: AppSpacing.xxl),

                            // Back/Cancel Button
                            Center(
                              child: TextButton(
                                onPressed: () => context.pop(),
                                child: Text(
                                  widget.mode ==
                                          PrimarySportSelectionMode.addPersona
                                      ? 'Cancel'
                                      : 'Back',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: tokens.main.primary,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: AppSpacing.xxl),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlowIndicator(ThemeData theme, dynamic tokens) {
    final addPersonaData = ref.read(addPersonaDataProvider);
    final label = addPersonaData?.targetPersona.displayName ?? 'Profile';

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: tokens.main.primary.withOpacity(0.15),
              borderRadius: AppRadius.small,
            ),
            child: Text(
              'Adding $label Profile',
              style: theme.textTheme.labelMedium?.copyWith(
                color: tokens.main.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Sports Radio List Widget
class _SportsRadioList extends StatelessWidget {
  final List<String> sports;
  final String? selectedSport;
  final Function(String) onSelect;
  final dynamic tokens;
  final ThemeData theme;

  const _SportsRadioList({
    required this.sports,
    required this.selectedSport,
    required this.onSelect,
    required this.tokens,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: sports.map((sport) {
        final isSelected = selectedSport == sport;

        return Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: _SportRadioCard(
            sport: sport,
            isSelected: isSelected,
            onSelect: () => onSelect(sport),
            tokens: tokens,
            theme: theme,
          ),
        );
      }).toList(),
    );
  }
}

// Sport Radio Card Widget
class _SportRadioCard extends StatelessWidget {
  final String sport;
  final bool isSelected;
  final VoidCallback onSelect;
  final dynamic tokens;
  final ThemeData theme;

  const _SportRadioCard({
    required this.sport,
    required this.isSelected,
    required this.onSelect,
    required this.tokens,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.main.surface,
          border: Border.all(
            color: isSelected
                ? tokens.main.primary
                : tokens.main.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            // Radio button indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? tokens.main.primary : tokens.main.outline,
                  width: 2,
                ),
                color: isSelected ? tokens.main.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tokens.main.onPrimary,
                        ),
                      ),
                    )
                  : null,
            ),

            SizedBox(width: AppSpacing.lg),

            // Emoji
            Text(
              AppHelpers.getSportEmoji(sport),
              style: const TextStyle(fontSize: 32),
            ),

            SizedBox(width: AppSpacing.lg),

            // Name
            Expanded(
              child: Text(
                AppHelpers.getSportDisplayName(sport),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: tokens.main.onSurface,
                ),
              ),
            ),

            // Primary badge
            if (isSelected) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: tokens.main.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 16, color: tokens.main.primary),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      'Primary',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tokens.main.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
