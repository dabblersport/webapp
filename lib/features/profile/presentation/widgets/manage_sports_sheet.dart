import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show sportsProvider;

/// Bottom sheet for adding/removing sports from the user's profile.
///
/// Updates both the profile `interests` array and the corresponding
/// `sport_profiles` / `organiser` records in the database.
class ManageSportsSheet extends ConsumerStatefulWidget {
  const ManageSportsSheet({super.key});

  @override
  ConsumerState<ManageSportsSheet> createState() => _ManageSportsSheetState();
}

class _ManageSportsSheetState extends ConsumerState<ManageSportsSheet> {
  /// Currently selected sport IDs (UUIDs).
  Set<String> _selectedIds = {};
  bool _isSaving = false;
  String? _profileId;
  String? _profileType;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must have at least one sport'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (isAdding) {
        // 1. Add UUID to interests array.
        final newInterests = {..._selectedIds, sport.id}.toList();
        await supabase
            .from('profiles')
            .update({'interests': newInterests})
            .eq('id', _profileId!);

        // 2. Create sport_profile / organiser record.
        if (!_isOrganiserType) {
          await supabase.from('sport_profiles').upsert({
            'profile_id': _profileId,
            'sport': sportKey,
            'skill_level': 1,
          }, onConflict: 'profile_id,sport');
        } else {
          await supabase.from('organiser').upsert({
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
            .from('profiles')
            .update({'interests': newInterests})
            .eq('id', _profileId!);

        // 2. Delete sport_profile / organiser record.
        if (!_isOrganiserType) {
          await supabase
              .from('sport_profiles')
              .delete()
              .eq('profile_id', _profileId!)
              .eq('sport', sportKey);
        } else {
          await supabase
              .from('organiser')
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update sport: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sportsAsync = ref.watch(sportsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Row(
                children: [
                  Text(
                    'Manage Sports',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (_isSaving)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Tap a sport to add or remove it from your profile.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Sports list
            Expanded(
              child: sportsAsync.when(
                data: (sports) => ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sports.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sport = sports[index];
                    final isSelected = _selectedIds.contains(sport.id);
                    return ListTile(
                      leading: Text(
                        sport.emoji ?? '🏅',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        sport.nameEn,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: colorScheme.primary)
                          : Icon(
                              Icons.circle_outlined,
                              color: colorScheme.outlineVariant,
                            ),
                      onTap: _isSaving ? null : () => _toggle(sport),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Failed to load sports',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
