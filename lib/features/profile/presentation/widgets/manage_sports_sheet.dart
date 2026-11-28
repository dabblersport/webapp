import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/features/profile/domain/services/sport_removal.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profiles_providers.dart';
import 'package:dabbler/features/sports/data/my_sports_rpc.dart';
import 'package:dabbler/features/profile/domain/services/sport_selection.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show activeSportsByProfileCountryProvider;

/// Bottom sheet for the profile's sports, in two sections (KAN-1061):
///
/// * **My sports**: the active `sport_profiles` cards (`hidden_at IS NULL`).
///   Adding calls `rpc_add_my_sport`, removing `rpc_remove_my_sport` (the card
///   is hidden, never deleted).
/// * **Following**: the profile's `interests`, through `rpc_follow_sport` /
///   `rpc_unfollow_sport`.
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
  /// Active cards (My sports).
  SportSelection _mine = SportSelection(const []);

  /// The profile's `interests` (Following).
  SportSelection _following = SportSelection(const []);
  bool _isSaving = false;
  String? _profileId;
  String? _profileType;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _primarySport;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  void _loadCurrent() {
    final profile = ref.read(profileControllerProvider).profile;
    _following = SportSelection(profile?.interests ?? const []);
    _mine = SportSelection(const []);
    _profileId = profile?.id;
    _primarySport = profile?.primarySport;
    _profileType = profile?.personaType ?? profile?.profileType ?? 'player';
    final id = _profileId;
    if (id == null) return;
    ref.read(sportProfilesRepositoryProvider).getSportIdsForProfile(id).then((
      r,
    ) {
      final ids = r.fold((_) => const <String>[], (v) => v);
      if (!mounted || ids.isEmpty) return;
      setState(() => _mine.mergeFromProvider(ids));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isOrganiserType =>
      _profileType == 'organiser' || _profileType == 'business';

  /// The client pre-check for instant feedback; the RPC checks again.
  SportOutcome? _preCheck(Sport sport, {required bool mine}) {
    if (sport.id == _primarySport) return SportOutcome.blockedPrimary;
    if (!mine && _mine.isTicked(sport.id)) {
      return SportOutcome.blockedInMySports;
    }
    final block = sportRemovalBlock(
      sportId: sport.id,
      selectedCount: (mine ? _mine : _following).count,
      profileType: _profileType ?? 'player',
      primarySport: _primarySport,
    );
    return block == null ? null : SportOutcome.blockedLast;
  }

  Future<void> _toggle(Sport sport, {required bool mine}) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    final profileId = _profileId;
    if (userId == null || profileId == null || _isSaving) return;

    final selection = mine ? _mine : _following;
    if (selection.isPending(sport.id)) return;
    final isAdding = !selection.isTicked(sport.id);

    final block = isAdding ? null : _preCheck(sport, mine: mine);
    if (block != null) {
      final message = manageSportsOutcomeMessage(
        block,
        AppLocalizations.of(context),
      );
      if (message != null) _toast(message);
      return;
    }

    setState(() {
      _isSaving = true;
      isAdding ? selection.startAdd(sport.id) : selection.startRemove(sport.id);
    });
    widget.saving.value = true;
    var ok = false;

    try {
      final rpc = MySportsRpc(supabase);
      final result = await (mine
          ? (isAdding
                ? rpc.add(profileId, sport.id)
                : rpc.remove(profileId, sport.id))
          : (isAdding
                ? rpc.follow(profileId, sport.id)
                : rpc.unfollow(profileId, sport.id)));
      final outcome = result.fold((_) => SportOutcome.invalid, (o) => o);
      ok = outcome == SportOutcome.done || outcome == SportOutcome.unchanged;
      if (!ok) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          _toast(
            manageSportsOutcomeMessage(outcome, l10n) ??
                (isAdding
                    ? l10n.manage_sports_add_failed
                    : l10n.manage_sports_remove_failed),
          );
        }
        return;
      }
      // rpc_add_my_sport follows the sport too.
      if (mine && isAdding) {
        _following.finish(sport.id, removing: false, ok: true);
      }

      // Refresh the relevant controller so the profile screen updates.
      if (!_isOrganiserType) {
        await ref
            .read(sportsProfileControllerProvider.notifier)
            .loadSportsProfiles(userId, profileId: profileId);
      } else {
        await ref
            .read(organiserProfileControllerProvider.notifier)
            .loadOrganiserProfiles(userId, profileId: profileId);
      }

      // Refresh profile so interests list updates in the UI.
      await ref.read(profileControllerProvider.notifier).refreshProfile();
    } catch (e) {
      // The write landed when ok is set: a refresh failure is not shown.
      if (mounted && !ok) {
        final l10n = AppLocalizations.of(context);
        _toast(
          isAdding
              ? l10n.manage_sports_add_failed
              : l10n.manage_sports_remove_failed,
        );
      }
    } finally {
      widget.saving.value = false;
      selection.finish(sport.id, removing: !isAdding, ok: ok);
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
    final sportsAsync = ref.watch(activeSportsByProfileCountryProvider);
    final l10n = AppLocalizations.of(context);

    // The DabblerSheet body is already a scroll view, so this shrink-wraps
    // (the old DraggableScrollableSheet hosted its own list).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerText(
          l10n.manage_sports_subtitle,
          style: DabblerType.subheadline,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        DabblerSearchField(
          controller: _searchController,
          enabled: !_isSaving,
          placeholder: l10n.manage_sports_search,
          onChanged: (value) {
            setState(() => _searchQuery = value.trim().toLowerCase());
          },
          onCleared: () => setState(() => _searchQuery = ''),
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        sportsAsync.when(
          skipLoadingOnReload: true,
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
                  l10n.manage_sports_no_match,
                  textAlign: TextAlign.center,
                  style: DabblerType.subheadline,
                  tone: DabblerTextTone.secondary,
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section(l10n.manage_sports_section_mine, filteredSports, true),
                const DabblerGap.v(DabblerSpacing.space5),
                _section(
                  l10n.manage_sports_section_following,
                  filteredSports,
                  false,
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
              l10n.manage_sports_load_failed,
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

  Widget _section(String title, List<Sport> sports, bool mine) {
    final selection = mine ? _mine : _following;
    return Column(
      key: ValueKey<String>(
        mine ? 'manage-sports-mine' : 'manage-sports-following',
      ),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerText(title, style: DabblerType.headline),
        const DabblerGap.v(DabblerSpacing.space3),
        Wrap(
          spacing: DabblerSpacing.space2,
          runSpacing: DabblerSpacing.space2,
          children: [
            for (final sport in sports)
              DabblerChip(
                label: sport.localizedName(context),
                selected: selection.isTicked(sport.id),
                // The primary sport is marked in My sports.
                leadingIcon: mine && sport.id == _primarySport
                    ? const DabblerIcon('star', weight: DabblerIconWeight.bold)
                    : null,
                onTap: () => _toggle(sport, mine: mine),
              ),
          ],
        ),
      ],
    );
  }
}

/// The message for a blocked or failed [outcome], or null when it landed.
String? manageSportsOutcomeMessage(SportOutcome outcome, AppLocalizations l) =>
    switch (outcome) {
      SportOutcome.done || SportOutcome.unchanged => null,
      SportOutcome.blockedPrimary => l.manage_sports_remove_primary,
      SportOutcome.blockedLast => l.manage_sports_last_sport,
      SportOutcome.blockedInMySports => l.manage_sports_unfollow_in_my_sports,
      SportOutcome.invalid => null,
    };
