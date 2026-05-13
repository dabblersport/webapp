import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/widgets/adaptive_auth_shell.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class IntentSelectionScreen extends ConsumerStatefulWidget {
  const IntentSelectionScreen({super.key});

  @override
  ConsumerState<IntentSelectionScreen> createState() =>
      _IntentSelectionScreenState();
}

class _IntentSelectionScreenState extends ConsumerState<IntentSelectionScreen> {
  String? _selectedPersona;
  bool _isLoading = false;
  bool _isLoadingData = true;

  // Persona options
  List<Map<String, dynamic>> get _personaOptions {
    return [
      {
        'value': 'compete',
        'title': 'Compete',
        'description': 'Join games, track your level, play regularly',
        'icon': Icons.sports_soccer,
      },
      {
        'value': 'organise',
        'title': 'Organise',
        'description': 'Create games, set rules, manage players',
        'icon': Icons.event,
      },
      {
        'value': 'host',
        'title': 'Host',
        'description': 'Manage venues, availability, and bookings',
        'icon': Icons.stadium,
      },
      {
        'value': 'socialise',
        'title': 'Socialise',
        'description': 'Follow sports, people, and communities',
        'icon': Icons.groups,
      },
    ];
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
        // Map intention back to persona if needed
        if (onboardingData.intention == 'organise') {
          setState(() {
            _selectedPersona = 'organiser';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedPersona == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).intent_select_role),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Map UI selection to persona_type (single source of truth)
      // Database uses only persona_type: 'player', 'organiser', 'hoster', 'socialiser'
      String personaType;
      if (_selectedPersona == 'compete') {
        personaType = 'player';
      } else if (_selectedPersona == 'organise') {
        personaType = 'organiser';
      } else if (_selectedPersona == 'host') {
        personaType = 'hoster';
      } else {
        // socialise
        personaType = 'socialiser';
      }

      // Store persona type in onboarding provider
      ref.read(onboardingDataProvider.notifier).setIntention(personaType);

      if (mounted) {
        // Navigate to interests selection screen
        context.push(RoutePaths.interestsSelection);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
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
                      const SizedBox(height: AppSpacing.xxxl),
                      // Screen Title
                      Text(
                        'What brings you here?',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                      SizedBox(height: AppSpacing.lg),
                      // Headline
                      Text(
                        'Help us tailor Dabbler',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Persona Options
                      ..._personaOptions.map((option) {
                        final isSelected = _selectedPersona == option['value'];

                        return Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.lg),
                          child: _PersonaCard(
                            persona: option['value']!,
                            title: option['title']!,
                            description: option['description']!,
                            icon: option['icon']!,
                            isSelected: isSelected,
                            onTap: () => setState(
                              () => _selectedPersona = option['value'],
                            ),
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        );
                      }),
                      const Spacer(),

                      // Continue Button
                      FilledButton(
                        onPressed: (_isLoading || _selectedPersona == null)
                            ? null
                            : _handleSubmit,
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
                            : Text(AppLocalizations.of(context).intent_continue),
                      ),

                      SizedBox(height: AppSpacing.lg),

                      // Back Button
                      Center(
                        child: TextButton(
                          onPressed: () => context.pop(),
                          child: Text(
                            'Back',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final String persona;
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _PersonaCard({
    required this.persona,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              //
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
