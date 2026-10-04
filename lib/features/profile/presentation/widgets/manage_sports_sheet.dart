import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show activeSportsByProfileCountryProvider;

/// Bottom sheet for adding/removing sports from the user's profile.
///
/// Updates both the profile `interests` array and the corresponding
/// `sport_profiles` / `organiser` records in the database.
class ManageSportsSheet extends ConsumerStatefulWidget {
  const ManageSportsSheet({super.key});

  /// Presents the sheet, content-sized.
  static Future<void> show(BuildContext context) {
    return showDabblerSheet<void>(
      context: context,
      detent: DabblerSheetDetent.content,
      builder: (_) => const ManageSportsSheet(),
    );
  }

  @override
  ConsumerState<ManageSportsSheet> createState() => _ManageSportsSheetState();
}

class _ManageSportsSheetState extends ConsumerState<ManageSportsSheet> {
  /// Currently selected sport IDs (UUIDs).
  Set<String> _selectedIds = {};
  bool _isSaving = false;
  String? _profileId;
  String? _profileType;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  void _loadCurrent() {
    final profile = ref.read(profileControllerProvider).profile;
    _selectedIds = Set<String>.from(profile?.interests ?? []);
    _profileId = profile?.id;
    _profileType = profile?.personaType ?? profile?.profileType ?? 'player';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isOrganiserType =>
      _profileType == 'organiser' || _profileType == 'business';

  Future<void> _toggle(Sport sport) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || _profileId == null) return;

    final sportKey =
        (sport.sportKey ?? sport.nameEn.toLowerCase().replaceAll(' ', '_'))
            .toLowerCase();

    final isAdding = !_selectedIds.contains(sport.id);

    // Prevent removing the last sport.
    if (!isAdding && _selectedIds.length <= 1) {
      if (mounted) {
        _toast('You must have at least one sport');
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (isAdding) {
        // 1. Add UUID to interests array.
        final newInterests = {..._selectedIds, sport.id}.toList();
        await supabase
            .from(SupabaseConfig.usersTable)
            .update({'interests': newInterests})
            .eq('id', _profileId!);

        // 2. Create sport_profile / organiser record.
        if (!_isOrganiserType) {
          await supabase.from(SupabaseConfig.sportProfilesTable).upsert({
            'profile_id': _profileId,
            'sport': sportKey,
            'skill_level': 1,
          }, onConflict: 'profile_id,sport');
        } else {
          await supabase.from(SupabaseConfig.organiserTable).upsert({
            'profile_id': _profileId,
            'sport': sportKey,
            'organiser_level': 1,
            'commission_type': 'percent',
            'commission_value': 0.0,
            'is_verified': false,
            'is_active': true,
          }, onConflict: 'profile_id,sport');
        }

        setState(() => _selectedIds.add(sport.id));
      } else {
        // 1. Remove UUID from interests array.
        final newInterests = _selectedIds
            .where((id) => id != sport.id)
            .toList();
        await supabase
            .from(SupabaseConfig.usersTable)
            .update({'interests': newInterests})
            .eq('id', _profileId!);

        // 2. Delete sport_profile / organiser record.
        if (!_isOrganiserType) {
          await supabase
              .from(SupabaseConfig.sportProfilesTable)
              .delete()
              .eq('profile_id', _profileId!)
              .eq('sport', sportKey);
        } else {
          await supabase
              .from(SupabaseConfig.organiserTable)
              .delete()
              .eq('profile_id', _profileId!)
              .eq('sport', sportKey);
        }

        setState(() => _selectedIds.remove(sport.id));
      }

      // Refresh the relevant controller so the profile screen updates.
      if (!_isOrganiserType) {
        await ref
            .read(sportsProfileControllerProvider.notifier)
            .loadSportsProfiles(userId, profileId: _profileId);
      } else {
        await ref
            .read(organiserProfileControllerProvider.notifier)
            .loadOrganiserProfiles(userId, profileId: _profileId);
      }

      // Refresh profile so interests list updates in the UI.
      await ref.read(profileControllerProvider.notifier).refreshProfile();
    } catch (e) {
      if (mounted) {
        _toast('Failed to update sport: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toast(String message) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: DabblerToastTone.error));
  }

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final sportsAsync = ref.watch(activeSportsByProfileCountryProvider);

    // The DabblerSheet body is already a scroll view, so this shrink-wraps
    // (the old DraggableScrollableSheet hosted its own list).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title row (handle and close come from DabblerSheet).
        Padding(
          padding: const EdgeInsetsDirectional.only(
            bottom: DabblerSpacing.space2,
          ),
          child: Row(
            children: [
              Expanded(
                child: DabblerText('Manage Sports', style: DabblerType.title3),
              ),
              if (_isSaving) const DabblerSpinner(size: DabblerSpinnerSize.sm),
            ],
          ),
        ),
        DabblerText(
          'Tap a sport to add or remove it from your profile.',
          style: DabblerType.subheadline,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        DabblerSearchField(
          controller: _searchController,
          enabled: !_isSaving,
          placeholder: 'Search sports',
          onChanged: (value) {
            setState(() => _searchQuery = value.trim().toLowerCase());
          },
          onCleared: () => setState(() => _searchQuery = ''),
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        sportsAsync.when(
          data: (sports) {
            final filteredSports = _searchQuery.isEmpty
                ? sports
                : sports
                      .where(
                        (sport) =>
                            sport.nameEn.toLowerCase().contains(_searchQuery) ||
                            (sport.emoji?.contains(_searchQuery) ?? false),
                      )
                      .toList();

            if (filteredSports.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(DabblerSpacing.space8),
                child: DabblerText(
                  'No sports match your search',
                  textAlign: TextAlign.center,
                  style: DabblerType.subheadline,
                  tone: DabblerTextTone.secondary,
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final sport in filteredSports)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: DabblerSpacing.space2,
                    ),
                    child: _sportRow(sport, colors),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(DabblerSpacing.space8),
            child: Center(child: DabblerSpinner()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(DabblerSpacing.space8),
            child: DabblerText(
              'Failed to load sports',
              textAlign: TextAlign.center,
              style: DabblerType.subheadline,
              tone: DabblerTextTone.secondary,
            ),
          ),
        ),
        const DabblerGap.v(DabblerSpacing.space5),
      ],
    );
  }

  Widget _sportRow(Sport sport, DabblerColors colors) {
    final isSelected = _selectedIds.contains(sport.id);
    final key = (sport.sportKey ?? sport.nameEn.toLowerCase())
        .toLowerCase()
        .replaceAll('_', '-')
        .replaceAll(' ', '-');
    return DabblerInputRow(
      // The sport emoji is replaced by the DS sport glyph.
      leading: DabblerSportIcon.fromKey(key),
      title: sport.nameEn,
      trailing: DabblerIcon(
        isSelected ? 'tick-circle' : 'record',
        weight: isSelected ? DabblerIconWeight.bold : DabblerIconWeight.linear,
        color: isSelected ? colors.brandPrimary : colors.textTertiary,
      ),
      enabled: !_isSaving,
      onTap: () => _toggle(sport),
    );
  }
}
