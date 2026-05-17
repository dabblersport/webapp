import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_widgets.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

enum InterestsSelectionMode { onboarding, addPersona }

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
  final Set<String> _selectedSportIds = {};
  bool _isLoading = false;
  List<Sport> _loadedSports = [];
  String _query = '';

  void _toggleSport(String sportId) {
    HapticFeedback.lightImpact();
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
          content: Text(AppLocalizations.of(context).interests_select_one),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sportIds = _selectedSportIds.toList();

      if (widget.mode == InterestsSelectionMode.addPersona) {
        ref.read(addPersonaDataProvider.notifier).setInterests(sportIds);
        if (mounted) context.push(RoutePaths.addPersonaPrimarySport);
      } else {
        final firstSport = _loadedSports.isNotEmpty
            ? _loadedSports.firstWhere(
                (s) => s.id == sportIds.first,
                orElse: () => _loadedSports.first,
              )
            : null;
        ref
            .read(onboardingDataProvider.notifier)
            .setSports(
              preferredSport: sportIds.first,
              interests: sportIds,
              preferredSportName: firstSport?.nameEn,
            );
        if (mounted) context.push(RoutePaths.onboardingPrimarySport);
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

  (String, String) _getPersonaSpecificCopy() {
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
      ref.read(addPersonaDataProvider.notifier).clear();
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _getPersonaSpecificCopy();
    final sportsAsync = ref.watch(sportsForSelectedCountryProvider);

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            OnboardingTopBar(onBack: _handleBack),
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
                data: (sports) {
                  _loadedSports = sports;
                  final filtered = _query.isEmpty
                      ? sports
                      : sports
                            .where(
                              (s) => s.nameEn.toLowerCase().contains(
                                _query.toLowerCase(),
                              ),
                            )
                            .toList();

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverToBoxAdapter(
                          child: OnboardingScreenHead(
                            eyebrow: 'Step 3 of 5',
                            title: title,
                            subtitle: subtitle,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                          child: _SearchPill(
                            query: _query,
                            selectedCount: _selectedSportIds.length,
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.8,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final sport = filtered[index];
                            final isSelected = _selectedSportIds.contains(
                              sport.id,
                            );
                            return _SportTile(
                              sport: sport,
                              isSelected: isSelected,
                              onTap: () => _toggleSport(sport.id),
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
                label: AppLocalizations.of(context).interests_continue,
                onPressed: (_isLoading || _selectedSportIds.isEmpty)
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

class _SearchPill extends StatefulWidget {
  const _SearchPill({
    required this.query,
    required this.selectedCount,
    required this.onChanged,
  });

  final String query;
  final int selectedCount;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<_SearchPill> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.query);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(16);
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Search sports…',
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
        prefixIcon: Icon(
          Iconsax.search_normal_1_copy,
          color: colorScheme.onSurfaceVariant,
          size: 20,
        ),
        suffixIcon: widget.selectedCount > 0
            ? Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${widget.selectedCount}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimary,
                  ),
                ),
              )
            : null,
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? accent.withValues(alpha: 0.10) : colorScheme.surfaceContainerLowest,
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
        child: Stack(
          children: [
            // Corner blob
            // Positioned(
            //   top: -10,
            //   right: -10,
            //   child: Container(
            //     width: 52,
            //     height: 52,
            //     decoration: BoxDecoration(
            //       shape: BoxShape.circle,
            //       color: accent.withValues(alpha: isSelected ? 0.18 : 0.08),
            //     ),
            //   ),
            // ),
            // Content
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: AnimatedContainer(
                    duration: duration,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
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
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: sport.emoji != null
                          ? Text(
                              sport.emoji!,
                              style: const TextStyle(fontSize: 16),
                            )
                          : Icon(
                              kSportIcons[sport.nameEn] ?? Iconsax.activity,
                              size: 16,
                              color: isSelected ? colorScheme.onPrimary : accent,
                            ),
                    ),
                  ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    sport.nameEn,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Check badge
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: CheckBadge(color: accent, size: 13),
              ),
          ],
        ),
      ),
    );
  }
}
