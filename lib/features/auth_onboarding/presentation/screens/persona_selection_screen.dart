import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/features/auth_onboarding/presentation/controllers/onboarding_controller.dart';

/// Screen for selecting persona type (player, organiser, or host)
/// STEP 3 in onboarding flow
class PersonaSelectionScreen extends ConsumerStatefulWidget {
  const PersonaSelectionScreen({super.key});

  @override
  ConsumerState<PersonaSelectionScreen> createState() =>
      _PersonaSelectionScreenState();
}

class _PersonaSelectionScreenState
    extends ConsumerState<PersonaSelectionScreen> {
  String? _selectedPersona;

  void _handleContinue() {
    if (_selectedPersona == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select how you want to use Dabbler'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Save persona selection
    ref
        .read(onboardingControllerProvider.notifier)
        .selectPersona(_selectedPersona!);

    // NOTE: After persona selection, user will proceed to existing screens
    // (create_user_information, sports_selection, etc.) which will collect
    // username, display_name, preferred_sports, interests
    //
    // Those screens should call:
    // ref.read(onboardingControllerProvider.notifier).setProfileData(...)
    //
    // Then finally call:
    // ref.read(onboardingControllerProvider.notifier).createProfile()

    // For now, navigate to existing create_user_information screen
    // TODO: Update create_user_information to integrate with onboarding controller
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    final backgroundColor = isDarkMode
        ? colorScheme.surface
        : const Color(0xFFF6F2FF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title
                        Text(
                          'Choose Your Role',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'How do you want to use Dabbler?',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 40),

                        // Persona Options
                        _PersonaCard(
                          persona: 'player',
                          title: 'Player',
                          description:
                              'Join games, build your sports profile, and connect with other players',
                          icon: Icons.sports_soccer,
                          isSelected: _selectedPersona == 'player',
                          onTap: () =>
                              setState(() => _selectedPersona = 'player'),
                        ),

                        const SizedBox(height: 16),

                        _PersonaCard(
                          persona: 'organiser',
                          title: 'Organiser',
                          description:
                              'Create and manage games, build your community, and organize events',
                          icon: Icons.event,
                          isSelected: _selectedPersona == 'organiser',
                          onTap: () =>
                              setState(() => _selectedPersona = 'organiser'),
                        ),

                        const SizedBox(height: 16),

                        _PersonaCard(
                          persona: 'host',
                          title: 'Venue Host',
                          description:
                              'List your venue, manage bookings, and connect with the sports community',
                          icon: Icons.stadium,
                          isSelected: _selectedPersona == 'host',
                          onTap: () =>
                              setState(() => _selectedPersona = 'host'),
                        ),

                        const SizedBox(height: 40),

                        // Continue Button
                        FilledButton(
                          onPressed: state.isLoading ? null : _handleContinue,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                          ),
                          child: state.isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Continue'),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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

  const _PersonaCard({
    required this.persona,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
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
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
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
