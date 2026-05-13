import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/widgets/adaptive_auth_shell.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/ui_constants.dart' show AppRadius;
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

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
  String? _selectedSportId; // UUID
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-select if only one sport is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final interestIds = _getInterestIds();
      if (interestIds.length == 1) {
        setState(() {
          _selectedSportId = interestIds.first;
        });
      }
    });
  }

  /// Get interest UUIDs from appropriate provider based on mode
  List<String> _getInterestIds() {
    if (widget.mode == PrimarySportSelectionMode.addPersona) {
      return ref.read(addPersonaDataProvider)?.interests ?? [];
    }
    return ref.read(onboardingDataProvider)?.interests ?? [];
  }

  /// Resolve interest UUIDs to Sport objects using the sports list
  List<Sport> _resolveInterestSports(List<Sport> allSports) {
    final interestIds = _getInterestIds();
    final sportMap = {for (final s in allSports) s.id: s};
    return interestIds
        .where((id) => sportMap.containsKey(id))
        .map((id) => sportMap[id]!)
        .toList();
  }

  void _selectSport(String sportId) {
    setState(() {
      _selectedSportId = sportId;
    });
  }

  Future<void> _handleContinue() async {
    if (_selectedSportId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).primary_sport_select_error),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.mode == PrimarySportSelectionMode.addPersona) {
        // ADD PERSONA MODE: Update addPersonaDataProvider with UUID
        ref
            .read(addPersonaDataProvider.notifier)
            .setPrimarySport(_selectedSportId!);

        if (mounted) {
          context.push(RoutePaths.addPersonaUsername);
        }
      } else {
        // ONBOARDING MODE: Update onboardingDataProvider with UUID
        ref
            .read(onboardingDataProvider.notifier)
            .setSports(
              preferredSport: _selectedSportId!,
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
    final colorScheme = theme.colorScheme;

    // Watch sports from Supabase to resolve UUIDs to display data
    final sportsAsync = ref.watch(sportsProvider);

    return sportsAsync.when(
      loading: () => Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Text(
            'Failed to load sports',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
      data: (allSports) {
        // Resolve interest UUIDs to Sport objects
        final selectedSports = _resolveInterestSports(allSports);

        // If no sports resolved, show error state
        if (selectedSports.isEmpty) {
          return Scaffold(
            backgroundColor: colorScheme.surface,
            body: Center(
              child: Text(
                'No sports selected. Please go back.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          );
        }

        return AdaptiveAuthShell(
          backgroundColor: colorScheme.surface,
          containerColor: colorScheme.secondaryContainer,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                            _buildFlowIndicator(theme, colorScheme),

                          // Title
                          Text(
                            'Choose your primary sport',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),

                          SizedBox(height: AppSpacing.lg),

                          // Subtitle
                          Text(
                            'This sport will appear on your profile and be used by default.',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),

                          SizedBox(height: AppSpacing.md),

                          // Helper text
                          Text(
                            'You can change it later.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSecondaryContainer
                                  .withValues(alpha: 0.7),
                            ),
                          ),

                          SizedBox(height: AppSpacing.xxl),

                          // Sports List (Radio-style selection)
                          _SportsRadioList(
                            sports: selectedSports,
                            selectedSportId: _selectedSportId,
                            onSelect: _selectSport,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),

                          const Spacer(),

                          // Continue Button
                          FilledButton(
                            onPressed: (_isLoading || _selectedSportId == null)
                                ? null
                                : _handleContinue,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              shape: const StadiumBorder(),
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              textStyle: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(AppLocalizations.of(context).primary_sport_continue),
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
                                  color: colorScheme.primary,
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
        );
      },
    );
  }

  Widget _buildFlowIndicator(ThemeData theme, ColorScheme colorScheme) {
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
              color: colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: AppRadius.small,
            ),
            child: Text(
              'Adding $label Profile',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Sports Radio List Widget - uses Sport objects
class _SportsRadioList extends StatelessWidget {
  final List<Sport> sports;
  final String? selectedSportId;
  final Function(String) onSelect;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _SportsRadioList({
    required this.sports,
    required this.selectedSportId,
    required this.onSelect,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: sports.map((sport) {
        final isSelected = selectedSportId == sport.id;

        return Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: _SportRadioCard(
            sport: sport,
            isSelected: isSelected,
            onSelect: () => onSelect(sport.id),
            colorScheme: colorScheme,
            theme: theme,
          ),
        );
      }).toList(),
    );
  }
}

// Sport Radio Card Widget - uses Sport object
class _SportRadioCard extends StatelessWidget {
  final Sport sport;
  final bool isSelected;
  final VoidCallback onSelect;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _SportRadioCard({
    required this.sport,
    required this.isSelected,
    required this.onSelect,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
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
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                  width: 2,
                ),
                color: isSelected ? colorScheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : null,
            ),

            SizedBox(width: AppSpacing.lg),

            // Emoji from DB
            Text(sport.emoji ?? '🏅', style: const TextStyle(fontSize: 32)),

            SizedBox(width: AppSpacing.lg),

            // Name from DB
            Expanded(
              child: Text(
                sport.nameEn,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: colorScheme.onSurface,
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
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 16, color: colorScheme.primary),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      'Primary',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
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
