import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/design_system/tokens/main_dark.dart'
    as main_dark_tokens;
import 'package:dabbler/design_system/tokens/main_light.dart'
    as main_light_tokens;
import 'package:dabbler/widgets/adaptive_auth_shell.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mode for the interests selection screen
enum InterestsSelectionMode {
  /// Onboarding flow - creates new user profile
  onboarding,

  /// Add persona flow - adds profile to existing user
  addPersona,
}

/// Screen for selecting sports interests during onboarding or add persona flow
///
/// UI + SELECTION ONLY - only updates profiles.interests field
///
/// Grouping Logic:
/// 1. "Popular in your region" - sports matching user's region
/// 2. "Other sports" - all remaining sports
class InterestsSelectionScreen extends ConsumerStatefulWidget {
  final InterestsSelectionMode mode;

  const InterestsSelectionScreen({
    super.key,
    this.mode = InterestsSelectionMode.onboarding,
  });

  @override
  ConsumerState<InterestsSelectionScreen> createState() =>
      _InterestsSelectionScreenState();
}

class _InterestsSelectionScreenState
    extends ConsumerState<InterestsSelectionScreen> {
  final Set<String> _selectedSportIds = {}; // UUIDs
  bool _isLoading = false;

  void _toggleSport(String sportId) {
    setState(() {
      if (_selectedSportIds.contains(sportId)) {
        _selectedSportIds.remove(sportId);
      } else {
        _selectedSportIds.add(sportId);
      }
    });
  }

  Future<void> _handleContinue() async {
    if (_selectedSportIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one sport'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sportIds = _selectedSportIds.toList();

      if (widget.mode == InterestsSelectionMode.addPersona) {
        // ADD PERSONA MODE: Just update provider, no DB write yet
        ref.read(addPersonaDataProvider.notifier).setInterests(sportIds);

        if (mounted) {
          context.push(RoutePaths.addPersonaPrimarySport);
        }
      } else {
        // ONBOARDING MODE: Store UUIDs in provider, navigate to primary sport
        ref
            .read(onboardingDataProvider.notifier)
            .setSports(preferredSport: sportIds.first, interests: sportIds);

        if (mounted) {
          context.push(RoutePaths.onboardingPrimarySport);
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

  /// Returns persona-aware title and subtitle
  (String, String) _getPersonaSpecificCopy() {
    // For add persona mode, use addPersonaDataProvider
    if (widget.mode == InterestsSelectionMode.addPersona) {
      final addPersonaData = ref.read(addPersonaDataProvider);
      final targetPersona = addPersonaData?.targetPersona;

      return switch (targetPersona) {
        PersonaType.player => (
          'What do you regularly practice?',
          'You can change and add more sports later',
        ),
        PersonaType.organiser => (
          'What do you intend to organise?',
          'You can change and add more sports later',
        ),
        PersonaType.hoster => (
          'Which sports do you host?',
          'You can change and add more sports later',
        ),
        PersonaType.socialiser => (
          'Which sports are you interested in?',
          'You can change and add more sports later',
        ),
        _ => (
          'What do you regularly practice?',
          'You can change and add more sports later',
        ),
      };
    }

    // For onboarding mode, use onboardingDataProvider
    final onboardingData = ref.read(onboardingDataProvider);
    final intention = onboardingData?.intention;

    return switch (intention) {
      'player' => (
        'What do you regularly practice?',
        'You can change and add more sports later',
      ),
      'organiser' => (
        'What do you intend to organise?',
        'You can change and add more sports later',
      ),
      'hoster' => (
        'Which sports do you host?',
        'You can change and add more sports later',
      ),
      'socialiser' => (
        'Which sports are you interested in?',
        'You can change and add more sports later',
      ),
      _ => (
        'What do you regularly practice?',
        'You can change and add more sports later',
      ),
    };
  }

  void _handleBack() {
    if (widget.mode == InterestsSelectionMode.addPersona) {
      // Clear add persona data and go back
      ref.read(addPersonaDataProvider.notifier).clear();
    }
    context.pop();
  }

  /// Build flow indicator badge for add persona mode
  Widget _buildFlowIndicator(ThemeData theme, dynamic tokens) {
    final addPersonaData = ref.read(addPersonaDataProvider);
    final targetPersona = addPersonaData?.targetPersona ?? PersonaType.player;
    final isConversion = addPersonaData?.isConversion ?? false;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isConversion
            ? tokens.main.tertiaryContainer
            : tokens.main.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConversion ? Icons.swap_horiz : Icons.add_circle_outline,
            size: 18,
            color: isConversion
                ? tokens.main.onTertiaryContainer
                : tokens.main.onPrimaryContainer,
          ),
          SizedBox(width: AppSpacing.xs),
          Text(
            isConversion
                ? 'Converting to ${targetPersona.displayName}'
                : 'Adding ${targetPersona.displayName} profile',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isConversion
                  ? tokens.main.onTertiaryContainer
                  : tokens.main.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

    // Get persona-specific copy
    final (title, subtitle) = _getPersonaSpecificCopy();

    // Watch sports from Supabase (loads Sport objects with UUID ids)
    final sportsAsync = ref.watch(sportsProvider);

    return AdaptiveAuthShell(
      backgroundColor: tokens.main.background,
      containerColor: tokens.main.secondaryContainer,
      child: sportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Failed to load sports',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: tokens.main.onSecondaryContainer,
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => ref.invalidate(sportsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (sports) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Flow indicator (only for add persona mode)
                if (widget.mode == InterestsSelectionMode.addPersona) ...[
                  _buildFlowIndicator(theme, tokens),
                  SizedBox(height: AppSpacing.lg),
                ],

                // Title (persona-specific)
                Text(
                  title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tokens.main.onSecondaryContainer,
                  ),
                ),

                SizedBox(height: AppSpacing.lg),

                // Subtitle (persona-specific)
                Text(
                  subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: tokens.main.onSecondaryContainer,
                  ),
                ),

                SizedBox(height: AppSpacing.xxxl),

                // Available sports section
                _SectionHeader(
                  title: 'Available sports',
                  tokens: tokens,
                  theme: theme,
                ),
                SizedBox(height: AppSpacing.md),
                _SportsGrid(
                  sports: sports,
                  selectedSportIds: _selectedSportIds,
                  onToggle: _toggleSport,
                  tokens: tokens,
                  theme: theme,
                ),

                SizedBox(height: AppSpacing.xxxl),

                // Selected count indicator
                if (_selectedSportIds.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: tokens.main.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: tokens.main.primary,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          '${_selectedSportIds.length} sport${_selectedSportIds.length > 1 ? 's' : ''} selected',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.main.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.xxl),
                ],

                // Continue Button
                FilledButton(
                  onPressed: (_isLoading || _selectedSportIds.isEmpty)
                      ? null
                      : _handleContinue,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: const StadiumBorder(),
                    backgroundColor: tokens.main.primary,
                    foregroundColor: tokens.main.onPrimary,
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),

                SizedBox(height: AppSpacing.xxl),

                // Back/Cancel Button
                Center(
                  child: TextButton(
                    onPressed: _handleBack,
                    child: Text(
                      widget.mode == InterestsSelectionMode.addPersona
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
  }
}

// Section Header Widget
class _SectionHeader extends StatelessWidget {
  final String title;
  final dynamic tokens;
  final ThemeData theme;

  const _SectionHeader({
    required this.title,
    required this.tokens,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: tokens.main.onSecondaryContainer,
      ),
    );
  }
}

// Sports Grid Widget - uses Sport objects from Supabase
class _SportsGrid extends StatelessWidget {
  final List<Sport> sports;
  final Set<String> selectedSportIds;
  final Function(String) onToggle;
  final dynamic tokens;
  final ThemeData theme;

  const _SportsGrid({
    required this.sports,
    required this.selectedSportIds,
    required this.onToggle,
    required this.tokens,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: sports.length,
      itemBuilder: (context, index) {
        final sport = sports[index];
        final isSelected = selectedSportIds.contains(sport.id);

        return _SportCard(
          sport: sport,
          isSelected: isSelected,
          onToggle: () => onToggle(sport.id),
          tokens: tokens,
          theme: theme,
        );
      },
    );
  }
}

// Sport Card Widget - uses Sport object from Supabase
class _SportCard extends StatelessWidget {
  final Sport sport;
  final bool isSelected;
  final VoidCallback onToggle;
  final dynamic tokens;
  final ThemeData theme;

  const _SportCard({
    required this.sport,
    required this.isSelected,
    required this.onToggle,
    required this.tokens,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.main.primaryContainer
              : tokens.main.primaryContainer.withOpacity(0.3),
          border: Border.all(
            color: isSelected
                ? tokens.main.primary
                : tokens.main.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji from DB (fallback to generic sports emoji)
            Text(sport.emoji ?? '🏅', style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),

            // Name from DB
            Text(
              sport.nameEn,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: tokens.main.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Selection indicator
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(Icons.check_circle, size: 16, color: tokens.main.primary),
            ],
          ],
        ),
      ),
    );
  }
}
