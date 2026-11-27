import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/profile/domain/services/sport_removal.dart';
import 'package:dabbler/features/profile/domain/services/sport_selection.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show activeSportsByProfileCountryProvider;
import 'package:dabbler/features/sports/presentation/providers/my_sports_provider.dart';

/// Bottom sheet for adding/removing sports from the user's profile.
///
/// Updates both the profile `interests` array and the corresponding
/// `sport_profiles` / `organiser` records in the database.
class ManageSportsSheet extends ConsumerStatefulWidget {
  const ManageSportsSheet({super.key, required this.saving});

  /// True while a change is being saved: the sheet's header shows a spinner
  /// beside the title, so the state lives here and the content updates it.
  final ValueNotifier<bool> saving;

  /// Presents the sheet, content-sized.
  static Future<void> show(BuildContext context) {
    final ValueNotifier<bool> saving = ValueNotifier<bool>(false);
    return showAppSheet<void>(
      context: context,
      title: AppLocalizations.of(context).manage_sports_title,
      detent: DabblerSheetDetent.content,
      titleWidget: Row(
        children: [
          Expanded(
            child: DabblerText(
              AppLocalizations.of(context).manage_sports_title,
              style: DabblerType.title3,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: saving,
            builder: (BuildContext context, bool on, Widget? _) => on
                ? const DabblerSpinner(size: DabblerSpinnerSize.sm)
                : const SizedBox.shrink(),
          ),
        ],
      ),
      builder: (_) => ManageSportsSheet(saving: saving),
    );
  }

  @override
  ConsumerState<ManageSportsSheet> createState() => _ManageSportsSheetState();
}

class _ManageSportsSheetState extends ConsumerState<ManageSportsSheet> {
  /// Currently selected sport IDs (UUIDs): the same union as
  /// [mySportsProvider] (interests, sport_profiles rows, primary sport).
  SportSelection _selection = SportSelection(const []);

  /// The profile's `interests` alone. Writes go to this set, never to
  /// [_selection], so a card-only sport is not copied into interests.
  Set<String> _interests = {};
  bool _isSaving = false;
  String? _profileId;
  String? _profileType;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _primarySport;
  String? _preferredSport;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  void _loadCurrent() {
    final profile = ref.read(profileControllerProvider).profile;
    _interests = Set<String>.from(profile?.interests ?? []);
    _selection = SportSelection(_interests);
    // KAN-1057: legacy profiles hold sport_profiles rows missing from
    // interests; tick those chips too, from the provider the nav uses.
    ref.listenManual<AsyncValue<MySports>>(mySportsProvider, (_, next) {
      final mine = next.valueOrNull;
      if (!mounted || mine == null || mine.sports.isEmpty) return;
      setState(() => _selection.mergeFromProvider(mine.sports.map((s) => s.id)));
    }, fireImmediately: true);
    _profileId = profile?.id;
    _primarySport = profile?.primarySport;
    _preferredSport = profile?.preferredSport;
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

    if (_selection.isPending(sport.id)) return;
    final isAdding = !_selection.isTicked(sport.id);

    final block = isAdding
        ? null
        : sportRemovalBlock(
            sportId: sport.id,
            selectedCount: _selection.count,
            profileType: _profileType ?? 'player',
            primarySport: _primarySport,
            preferredSport: _preferredSport,
          );
    if (block != null) {
      if (mounted) {
        _toast(switch (block) {
          SportRemovalBlock.lastSport => AppLocalizations.of(
            context,
          ).manage_sports_last_sport,
          SportRemovalBlock.primarySport => AppLocalizations.of(
            context,
          ).manage_sports_remove_primary,
        });
      }
      return;
    }

    setState(() {
      _isSaving = true;
      isAdding
          ? _selection.startAdd(sport.id)
          : _selection.startRemove(sport.id);
    });
    widget.saving.value = true;
    var ok = false;

    try {
      if (isAdding) {
        // 1. Add UUID to interests array.
        final newInterests = {..._interests, sport.id}.toList();
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

        _interests.add(sport.id);
        ok = true;
      } else {
        // Row first, then interests: the contributor trigger requires every
        // sport row to have its sport in interests (KAN-1051).
        final newInterests = _interests.where((id) => id != sport.id).toList();
        final result = await removeSportInOrder(
          _SupabaseSportRemovalSteps(
            client: supabase,
            profileId: _profileId!,
            sportKey: sportKey,
            organiser: _isOrganiserType,
          ),
          newInterests,
        );
        if (result.isFailure) {
          throw Exception((result as Err<Unit, Failure>).error.message);
        }

        _interests.remove(sport.id);
        // The write landed: a later refresh failure must not re-tick it.
        ok = true;
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
        final l10n = AppLocalizations.of(context);
        _toast(
          isAdding
              ? l10n.manage_sports_add_failed
              : l10n.manage_sports_remove_failed,
        );
      }
    } finally {
      widget.saving.value = false;
      _selection.finish(sport.id, removing: !isAdding, ok: ok);
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
        DabblerText(
          AppLocalizations.of(context).manage_sports_subtitle,
          style: DabblerType.subheadline,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        DabblerSearchField(
          controller: _searchController,
          enabled: !_isSaving,
          placeholder: AppLocalizations.of(context).manage_sports_search,
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
                            sport
                                .localizedName(context)
                                .toLowerCase()
                                .contains(_searchQuery) ||
                            (sport.emoji?.contains(_searchQuery) ?? false),
                      )
                      .toList();

            if (filteredSports.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(DabblerSpacing.space8),
                child: DabblerText(
                  AppLocalizations.of(context).manage_sports_no_match,
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
              AppLocalizations.of(context).manage_sports_load_failed,
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
    final isSelected = _selection.isTicked(sport.id);
    final key = (sport.sportKey ?? sport.nameEn.toLowerCase())
        .toLowerCase()
        .replaceAll('_', '-')
        .replaceAll(' ', '-');
    return DabblerInputRow(
      // The sport emoji is replaced by the DS sport glyph.
      leading: DabblerSportIcon.fromKey(key),
      title: sport.localizedName(context),
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

/// Supabase implementation of [SportRemovalSteps] for one profile and sport.
class _SupabaseSportRemovalSteps implements SportRemovalSteps {
  _SupabaseSportRemovalSteps({
    required this.client,
    required this.profileId,
    required this.sportKey,
    required this.organiser,
  });

  final SupabaseClient client;
  final String profileId;
  final String sportKey;
  final bool organiser;

  String get _table => organiser
      ? SupabaseConfig.organiserTable
      : SupabaseConfig.sportProfilesTable;

  @override
  Future<List<Map<String, dynamic>>> deleteSportRecord() async {
    final rows = await client
        .from(_table)
        .delete()
        .eq('profile_id', profileId)
        .eq('sport', sportKey)
        .select();
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<void> updateInterests(List<String> interests) => client
      .from(SupabaseConfig.usersTable)
      .update({'interests': interests})
      .eq('id', profileId);

  @override
  Future<void> restoreSportRecord(List<Map<String, dynamic>> rows) =>
      client.from(_table).insert(rows);
}
