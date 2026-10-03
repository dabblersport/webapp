import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profile_view_provider.dart';
import 'package:dabbler/features/profile/presentation/widgets/sport_achievements_section.dart';
import 'package:dabbler/features/profile/presentation/widgets/sport_activity_section.dart';
import 'package:dabbler/features/profile/presentation/widgets/sport_game_history_section.dart';
import 'package:dabbler/features/profile/presentation/widgets/sport_profile_section_widgets.dart';

/// Sport profile tracker (design frame X06, "Sport Profile v2").
///
/// DS page with a titled top bar, a display sport header, a segmented
/// [DabblerTabs] strip (Tracker / Achievements / History) and the existing
/// sections beneath it. The design's "Personal bests" tab, minutes-played
/// card, drill rail and recent-matches rail have no data source in the app and
/// are not built. The legacy wide-layout wrapper is dropped as in
/// the earlier waves; the app shell owns navigation.
class SportProfileScreen extends ConsumerStatefulWidget {
  const SportProfileScreen({super.key, required this.args});

  final SportProfileRouteArgs args;

  @override
  ConsumerState<SportProfileScreen> createState() => _SportProfileScreenState();
}

class _SportProfileScreenState extends ConsumerState<SportProfileScreen> {
  static const String _tabTracker = 'tracker';
  static const String _tabAchievements = 'achievements';
  static const String _tabHistory = 'history';

  String _tab = _tabTracker;

  SportProfileRouteArgs get args => widget.args;

  @override
  Widget build(BuildContext context) {
    final core = ref.watch(sportProfileCoreProvider(args));
    final isOwnProfile =
        Supabase.instance.client.auth.currentUser?.id == args.userId;

    // The page paints immediately; each section resolves independently so a
    // slow query (e.g. post enrichment) never blocks the header/scoreboard.
    return DabblerPage(
      // The display sport name below is the title (the design fades a nav
      // title in on scroll); an empty one keeps the titled bar's back button.
      topBar: DabblerNavigationTopBar.titled(
        title: '',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DabblerSpacing.space6,
          DabblerSpacing.space4,
          DabblerSpacing.space6,
          DabblerSpacing.space11,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(args: args, data: core.valueOrNull),
                  const SizedBox(height: DabblerSpacing.space6),
                  DabblerTabs(
                    variant: DabblerTabsVariant.segmented,
                    value: _tab,
                    onChanged: (id) => setState(() => _tab = id),
                    items: const [
                      DabblerTabItem(id: _tabTracker, label: 'Tracker'),
                      DabblerTabItem(
                        id: _tabAchievements,
                        label: 'Achievements',
                      ),
                      DabblerTabItem(id: _tabHistory, label: 'History'),
                    ],
                  ),
                  const SizedBox(height: DabblerSpacing.space6),
                  ..._tabContent(context, core, isOwnProfile),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _tabContent(
    BuildContext context,
    AsyncValue<SportProfileCoreData> core,
    bool isOwnProfile,
  ) {
    switch (_tab) {
      case _tabAchievements:
        return [SportAchievementsSection(args: args)];
      case _tabHistory:
        // Game history — shown on every profile; the provider only
        // returns games the viewer is allowed to see.
        return [
          SportGameHistorySection(args: args),
          const SizedBox(height: DabblerSpacing.space6),
          SportActivitySection(args: args),
        ];
      case _tabTracker:
      default:
        return [
          core.when(
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SportSectionCard(
                  title: 'Scoreboard',
                  child: data.metrics.isEmpty
                      ? const SportEmptySection(
                          icon: 'chart',
                          message: 'No scoreboard data yet.',
                        )
                      : _ScoreboardGrid(metrics: data.metrics),
                ),
                // Per-sport preferences (own profile only — private settings)
                if (isOwnProfile)
                  Padding(
                    padding: const EdgeInsets.only(top: DabblerSpacing.space6),
                    child: _SportPreferencesSection(args: args, data: data),
                  ),
              ],
            ),
            loading: () => const SportSectionCard(
              title: 'Scoreboard',
              child: SportSectionLoading(),
            ),
            error: (error, _) => DabblerEmptyState.error(
              title: 'Failed to load sport profile',
              text: '$error',
              size: DabblerEmptyStateSize.inline,
            ),
          ),
        ];
    }
  }
}

class _ScoreboardGrid extends StatelessWidget {
  const _ScoreboardGrid({required this.metrics});

  final List<SportProfileMetric> metrics;

  @override
  Widget build(BuildContext context) {
    // Bento: two tiles per row (span 3 of the 6-column grid).
    return DabblerStatGrid(
      children: [
        for (final metric in metrics)
          DabblerStatTile(
            value: metric.value,
            label: metric.label,
            span: 3,
            rows: 1,
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.args, required this.data});

  final SportProfileRouteArgs args;
  final SportProfileCoreData? data;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final loaded = data;

    final String? subtitle = loaded == null
        ? null
        : (args.isOrganiserPersona
              ? _organiserSubtitle(loaded.organiserProfile)
              : _playerSubtitle(loaded.playerProfile));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          args.sportName,
          style: sportProfileText(
            context,
            DabblerType.largeTitle,
            colors.textPrimary,
          ),
        ),
        const SizedBox(height: DabblerSpacing.space4),
        Row(
          children: [
            DabblerAvatar(
              seed: args.displayName,
              imageUrl: args.avatarUrl,
              size: DabblerAvatarSize.md,
            ),
            const SizedBox(width: DabblerSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    args.displayName,
                    style: sportProfileText(
                      context,
                      DabblerType.headline,
                      colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: sportProfileText(
                        context,
                        DabblerType.footnote,
                        colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: DabblerSpacing.space4),
        Wrap(
          spacing: DabblerSpacing.space2,
          runSpacing: DabblerSpacing.space2,
          children: [
            DabblerBadge(
              label: args.isOrganiserPersona
                  ? 'Organiser persona'
                  : 'Player persona',
              tone: DabblerBadgeTone.withIcon,
            ),
            if (loaded?.playerTier != null)
              DabblerBadge(
                label: loaded!.playerTier!.key.toUpperCase(),
                tone: DabblerBadgeTone.defaultTone,
              ),
            if (loaded?.organiserProfile?.isVerified == true)
              DabblerBadge(
                label: 'Verified',
                status: colors.info,
                icon: const DabblerIcon(
                  'verify',
                  weight: DabblerIconWeight.bold,
                  size: 14,
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _playerSubtitle(dynamic playerProfile) {
    if (playerProfile == null) {
      return 'Read-only sport profile';
    }
    final primaryPosition = playerProfile.primaryPosition as String;
    final level = (playerProfile.overallLevel as double).toStringAsFixed(1);
    if (primaryPosition.isNotEmpty) {
      return 'Overall level $level • $primaryPosition';
    }
    return 'Overall level $level';
  }

  static String _organiserSubtitle(dynamic organiserProfile) {
    if (organiserProfile == null) {
      return 'Read-only organiser sport profile';
    }
    final level = organiserProfile.organiserLevel as int;
    final status = organiserProfile.isActive == true ? 'Active' : 'Inactive';
    return 'Organiser level $level • $status';
  }
}

/// Editable per-sport preferences: skill level and preferred position.
class _SportPreferencesSection extends ConsumerStatefulWidget {
  const _SportPreferencesSection({required this.args, required this.data});

  final SportProfileRouteArgs args;
  final SportProfileCoreData data;

  @override
  ConsumerState<_SportPreferencesSection> createState() =>
      _SportPreferencesSectionState();
}

class _SportPreferencesSectionState
    extends ConsumerState<_SportPreferencesSection> {
  int _skillLevel = 1;
  String? _position;
  bool _isSaving = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loadFromProfile();
      _loaded = true;
    }
  }

  void _loadFromProfile() {
    final player = widget.data.playerProfile;
    if (player != null && !widget.args.isOrganiserPersona) {
      _skillLevel = _skillFromProfile(player);
      _position = _positionFromProfile(player);
    }
    final organiser = widget.data.organiserProfile;
    if (organiser != null && widget.args.isOrganiserPersona) {
      _skillLevel = organiser.organiserLevel;
    }
  }

  int _skillFromProfile(dynamic player) {
    final raw = player.skillLevel;
    if (raw is int && raw >= 1 && raw <= 3) return raw;
    return 1;
  }

  String? _positionFromProfile(dynamic player) {
    final pos = player.primaryPosition as String?;
    if (pos != null && pos.isNotEmpty) return pos;
    return null;
  }

  List<String> get _availablePositions {
    switch (widget.args.sportKey.toLowerCase()) {
      case 'football':
        return ['Goalkeeper', 'Defender', 'Midfielder', 'Forward'];
      case 'basketball':
        return [
          'Point Guard',
          'Shooting Guard',
          'Small Forward',
          'Power Forward',
          'Center',
        ];
      case 'volleyball':
        return [
          'Setter',
          'Outside Hitter',
          'Middle Blocker',
          'Opposite Hitter',
          'Libero',
        ];
      default:
        return [];
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;

      if (widget.args.isOrganiserPersona) {
        await supabase
            .from(SupabaseConfig.organiserTable)
            .update({'organiser_level': _skillLevel})
            .eq('profile_id', widget.args.profileId)
            .eq('sport', widget.args.sportKey.toLowerCase());
      } else {
        final updates = <String, dynamic>{'skill_level': _skillLevel};
        if (_position != null) {
          updates['primary_position'] = _position;
        }
        await supabase
            .from(SupabaseConfig.sportProfilesTable)
            .update(updates)
            .eq('profile_id', widget.args.profileId)
            .eq('sport', widget.args.sportKey.toLowerCase());
      }

      // Invalidate the core provider; achievements re-derives from it.
      ref.invalidate(sportProfileCoreProvider(widget.args));

      if (mounted) {
        DabblerToastProvider.of(context).show(
          const DabblerToastSpec(
            message: 'Preferences saved',
            tone: DabblerToastTone.success,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(
            message: 'Failed to save: $e',
            tone: DabblerToastTone.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static const _skillLabels = {1: 'Beginner', 2: 'Intermediate', 3: 'Advanced'};

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final positions = _availablePositions;

    return SportSectionCard(
      title: 'Preferences',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skill level chips
          Text(
            widget.args.isOrganiserPersona ? 'Organiser Level' : 'Skill Level',
            style: sportProfileText(
              context,
              DabblerType.subheadline,
              colors.textPrimary,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: DabblerSpacing.space2),
          Wrap(
            spacing: DabblerSpacing.space2,
            runSpacing: DabblerSpacing.space2,
            children: _skillLabels.entries.map((entry) {
              return DabblerChip(
                label: entry.value,
                selected: _skillLevel == entry.key,
                onTap: () => setState(() => _skillLevel = entry.key),
              );
            }).toList(),
          ),
          // Position selector (player only, sports that have positions)
          if (!widget.args.isOrganiserPersona && positions.isNotEmpty) ...[
            const SizedBox(height: DabblerSpacing.space6),
            Text(
              'Preferred Position',
              style: sportProfileText(
                context,
                DabblerType.subheadline,
                colors.textPrimary,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: DabblerSpacing.space2),
            Wrap(
              spacing: DabblerSpacing.space2,
              runSpacing: DabblerSpacing.space2,
              children: positions.map((pos) {
                final isSelected = _position == pos;
                return DabblerChip(
                  label: pos,
                  selected: isSelected,
                  onTap: () =>
                      setState(() => _position = isSelected ? null : pos),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: DabblerSpacing.space6),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DabblerButton(
              label: 'Save',
              loading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}
