import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/widgets/onboarding_progress.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/design_system/tokens/main_dark.dart'
    as main_dark_tokens;
import 'package:dabbler/design_system/tokens/main_light.dart'
    as main_light_tokens;
import 'package:dabbler/utils/ui_constants.dart' hide AppSpacing;

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
        const SnackBar(
          content: Text('Please select your role'),
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
    final isDark = theme.brightness == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: tokens.main.background,
        body: Center(
          child: CircularProgressIndicator(color: tokens.main.primary),
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
            child: SafeArea(
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
                              const SizedBox(height: AppSpacing.xxxl),
                              // Screen Title
                              Text(
                                'What brings you here?',
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: tokens.main.onSecondaryContainer,
                                ),
                              ),
                              SizedBox(height: AppSpacing.lg),
                              // Headline
                              Text(
                                'Help us tailor Dabbler',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: tokens.main.onSecondaryContainer,
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Persona Options
                              ..._personaOptions.map((option) {
                                final isSelected =
                                    _selectedPersona == option['value'];

                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: AppSpacing.lg,
                                  ),
                                  child: _PersonaCard(
                                    persona: option['value']!,
                                    title: option['title']!,
                                    description: option['description']!,
                                    icon: option['icon']!,
                                    isSelected: isSelected,
                                    onTap: () => setState(
                                      () => _selectedPersona = option['value'],
                                    ),
                                    tokens: tokens,
                                    theme: theme,
                                  ),
                                );
                              }),
                              const Spacer(),

                              // Continue Button
                              FilledButton(
                                onPressed:
                                    (_isLoading || _selectedPersona == null)
                                    ? null
                                    : _handleSubmit,
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

                              SizedBox(height: AppSpacing.lg),

                              // Back Button
                              Center(
                                child: TextButton(
                                  onPressed: () => context.pop(),
                                  child: Text(
                                    'Back',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: tokens.main.primary,
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
            ),
          ),
        ),
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
  final dynamic tokens;
  final ThemeData theme;

  const _PersonaCard({
    required this.persona,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tokens,
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
                ? tokens.main.primary.withOpacity(0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? tokens.main.primary : tokens.main.outline,
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
                            ? tokens.main.primary
                            : tokens.main.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.main.onSecondaryContainer.withOpacity(
                          0.7,
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
