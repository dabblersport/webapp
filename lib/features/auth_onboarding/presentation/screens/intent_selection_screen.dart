import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_widgets.dart';

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

  static const _personaOptions = [
    _PersonaOption(
      value: 'compete',
      title: 'Compete',
      description: 'Join games, track your level, play regularly',
      icon: Icons.sports_score,
      accent: Color(0xFFFF3376),
    ),
    _PersonaOption(
      value: 'organise',
      title: 'Organise',
      description: 'Create games, set rules, manage players',
      icon: Icons.groups,
      accent: Color(0xFF7328CE),
    ),
    _PersonaOption(
      value: 'host',
      title: 'Host',
      description: 'Manage venues, availability, and bookings',
      icon: Icons.storefront,
      accent: Color(0xFF00B0FF),
    ),
    _PersonaOption(
      value: 'socialise',
      title: 'Socialise',
      description: 'Follow sports, people, and communities',
      icon: Icons.forum,
      accent: Color(0xFF00C853),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingUserData();
  }

  Future<void> _loadExistingUserData() async {
    try {
      final onboardingData = ref.read(onboardingDataProvider);
      if (onboardingData?.intention != null &&
          onboardingData!.intention!.isNotEmpty) {
        if (onboardingData.intention == 'organise') {
          setState(() => _selectedPersona = 'organiser');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
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
      String personaType;
      if (_selectedPersona == 'compete') {
        personaType = 'player';
      } else if (_selectedPersona == 'organise') {
        personaType = 'organiser';
      } else if (_selectedPersona == 'host') {
        personaType = 'hoster';
      } else {
        personaType = 'socialiser';
      }
      ref.read(onboardingDataProvider.notifier).setIntention(personaType);
      if (mounted) context.push(RoutePaths.interestsSelection);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
          children: [
            OnboardingTopBar(onBack: () => context.pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const OnboardingScreenHead(
                      eyebrow: 'Step 2 of 5',
                      title: 'What brings you here?',
                      subtitle:
                          'Help us tailor Dabbler. You can pick more than one later in settings.',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: Column(
                        children: _personaOptions
                            // Temporarily hidden: 'organise' and 'host'.
                            // Keep entries in _personaOptions so re-enabling
                            // is a one-line revert.
                            .where((o) => o.value != 'organise' && o.value != 'host')
                            .map((opt) {
                          final on = _selectedPersona == opt.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _IntentCard(
                              option: opt,
                              selected: on,
                              onTap: () =>
                                  setState(() => _selectedPersona = opt.value),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            OnboardingBottomBar(
              child: OnboardingCTAButton(
                label: AppLocalizations.of(context).intent_continue,
                onPressed: (_isLoading || _selectedPersona == null)
                    ? null
                    : _handleSubmit,
                isLoading: _isLoading,
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonaOption {
  final String value;
  final String title;
  final String description;
  final IconData icon;
  final Color accent;

  const _PersonaOption({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
  });
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PersonaOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? option.accent.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerLowest,
          border: Border.all(
            color: selected ? option.accent : colorScheme.outlineVariant,
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: option.accent.withValues(alpha: 0.25),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: selected ? null : option.accent.withValues(alpha: 0.10),
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          option.accent,
                          option.accent.withValues(alpha: 0.8),
                        ],
                      )
                    : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: option.accent.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                option.icon,
                size: 26,
                color: selected ? colorScheme.onPrimary : option.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? option.accent : Colors.transparent,
                border: selected
                    ? null
                    : Border.all(color: colorScheme.outline, width: 1.5),
              ),
              child: selected
                  ? Icon(Icons.check, size: 14, color: colorScheme.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
