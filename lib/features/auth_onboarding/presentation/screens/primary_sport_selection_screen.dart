import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_widgets.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

enum PrimarySportSelectionMode { onboarding, addPersona }

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
  String? _selectedSportId;
  bool _isLoading = false;

  List<String> _getInterestIds() {
    if (widget.mode == PrimarySportSelectionMode.addPersona) {
      return ref.read(addPersonaDataProvider)?.interests ?? [];
    }
    return ref.read(onboardingDataProvider)?.interests ?? [];
  }

  List<Sport> _resolveInterestSports(List<Sport> allSports) {
    final interestIds = _getInterestIds();
    final sportMap = {for (final s in allSports) s.id: s};
    return interestIds
        .where((id) => sportMap.containsKey(id))
        .map((id) => sportMap[id]!)
        .toList();
  }

  void _selectSport(String sportId) {
    HapticFeedback.lightImpact();
    setState(() => _selectedSportId = sportId);
  }

  Future<void> _handleContinue() async {
    if (_selectedSportId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).primary_sport_select_error,
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.mode == PrimarySportSelectionMode.addPersona) {
        ref
            .read(addPersonaDataProvider.notifier)
            .setPrimarySport(_selectedSportId!);
        if (mounted) context.push(RoutePaths.addPersonaUsername);
      } else {
        ref
            .read(onboardingDataProvider.notifier)
            .setSports(
              preferredSport: _selectedSportId!,
              interests: ref.read(onboardingDataProvider)?.interests,
            );
        if (mounted) context.push(RoutePaths.setUsername);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sportsAsync = ref.watch(sportsForSelectedCountryProvider);

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            OnboardingTopBar(onBack: () => context.pop()),
            Expanded(
              child: sportsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Failed to load sports',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(sportsForSelectedCountryProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (allSports) {
                  final sports = _resolveInterestSports(allSports);

                  if (sports.length == 1 && _selectedSportId == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _selectedSportId = sports.first.id);
                      }
                    });
                  }

                  if (sports.isEmpty) {
                    return Center(
                      child: Text(
                        'No sports selected. Please go back.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    );
                  }

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(24),
                        sliver: SliverToBoxAdapter(
                          child: OnboardingScreenHead(
                            eyebrow:
                                widget.mode ==
                                    PrimarySportSelectionMode.addPersona
                                ? 'Primary Sport'
                                : 'Step 4 of 5',
                            title: AppLocalizations.of(
                              context,
                            ).primary_sport_title,
                            subtitle: AppLocalizations.of(
                              context,
                            ).primary_sport_subtitle,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        sliver: SliverList.separated(
                          itemCount: sports.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final sport = sports[index];
                            final isSelected = _selectedSportId == sport.id;
                            return _SportTile(
                              sport: sport,
                              isSelected: isSelected,
                              onTap: () => _selectSport(sport.id),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            OnboardingBottomBar(
              child: OnboardingCTAButton(
                label: AppLocalizations.of(context).primary_sport_continue,
                onPressed: (_isLoading || _selectedSportId == null)
                    ? null
                    : _handleContinue,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SportTile extends StatelessWidget {
  const _SportTile({
    required this.sport,
    required this.isSelected,
    required this.onTap,
  });

  final Sport sport;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = kSportColors[sport.nameEn] ?? colorScheme.primary;
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? accent.withValues(alpha: 0.10)
              : colorScheme.surfaceContainerLowest,
          border: Border.all(
            color: isSelected ? accent : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
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
              duration: duration,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? null : accent.withValues(alpha: 0.12),
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, accent.withValues(alpha: 0.8)],
                      )
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.40),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: sport.emoji != null
                    ? Text(sport.emoji!, style: const TextStyle(fontSize: 22))
                    : Icon(
                        kSportIcons[sport.nameEn] ?? Iconsax.activity,
                        size: 22,
                        color: isSelected ? colorScheme.onPrimary : accent,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                sport.nameEn,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (isSelected) CheckBadge(color: accent, size: 20),
          ],
        ),
      ),
    );
  }
}
