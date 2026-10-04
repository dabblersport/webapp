import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/profile/presentation/screens/settings/profile_sports_screen.dart'
    show SkillLevel, SportPreference;

/// The design-system widget tree of [ProfileSportsScreen] (no design frame:
/// DS defaults). Pure presentation: all state and every action stay in the
/// screen's state object and arrive here as values and callbacks.
class ProfileSportsView extends StatelessWidget {
  const ProfileSportsView({
    super.key,
    required this.isLoading,
    required this.sportPreferences,
    required this.expanded,
    required this.showCreateGame,
    required this.positionsFor,
    required this.onBack,
    required this.onSave,
    required this.onCreateGame,
    required this.onToggleExpanded,
    required this.onSportEnabledChanged,
    required this.onSkillLevelSelected,
    required this.onPositionChanged,
  });

  final bool isLoading;
  final Map<String, SportPreference> sportPreferences;
  final Set<String> expanded;
  final bool showCreateGame;
  final List<String> Function(String sportKey) positionsFor;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onCreateGame;
  final ValueChanged<String> onToggleExpanded;
  final void Function(String sportKey, SportPreference pref, bool value)
  onSportEnabledChanged;
  final void Function(String sportKey, SportPreference pref, SkillLevel level)
  onSkillLevelSelected;
  final void Function(String sportKey, SportPreference pref, String? position)
  onPositionChanged;

  static const EdgeInsetsGeometry _gutter = EdgeInsetsDirectional.fromSTEB(
    DabblerSpacing.space6,
    DabblerSpacing.space4,
    DabblerSpacing.space6,
    DabblerSpacing.floatingBarClearance,
  );

  @override
  Widget build(BuildContext context) {
    // One layout at every width: the wide-screen rail wrapper
    // is not a DS component (same call as sports_library_screen, W5).
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        border: true,
        title: 'Sports Preferences',
        onBack: onBack,
        actions: [
          // A spinner replaces Save while busy, as the original did.
          DabblerNavigationAction.text(
            label: 'Save',
            loading: isLoading,
            onPressed: isLoading ? null : onSave,
          ),
        ],
      ),
      bottomOverlay: showCreateGame
          ? DabblerButton(
              label: 'Create game',
              icon: 'add-circle',
              onPressed: onCreateGame,
            )
          : null,
      body: isLoading && sportPreferences.isEmpty
          ? const Center(child: DabblerSpinner())
          : ListView(
              padding: _gutter,
              children: [
                _Header(
                  showCreateGame: showCreateGame,
                  onCreateGame: onCreateGame,
                ),
                const SizedBox(height: DabblerSpacing.space8),
                DabblerSection(
                  title: 'My Sports',
                  subtitle:
                      'Enable sports you want to play and set your skill level',
                  children: [
                    for (final entry in sportPreferences.entries)
                      _SportItem(
                        sportKey: entry.key,
                        preference: entry.value,
                        expanded: expanded.contains(entry.key),
                        positions: positionsFor(entry.key),
                        onToggleExpanded: () => onToggleExpanded(entry.key),
                        onEnabledChanged: (v) =>
                            onSportEnabledChanged(entry.key, entry.value, v),
                        onSkillLevel: (l) =>
                            onSkillLevelSelected(entry.key, entry.value, l),
                        onPosition: (p) =>
                            onPositionChanged(entry.key, entry.value, p),
                      ),
                  ],
                ),
                const SizedBox(height: DabblerSpacing.space8),
                DabblerSection(
                  title: 'General Preferences',
                  children: [
                    // These three switches were inert in the old screen
                    // (no-op onChanged); kept inert, same values.
                    _staticToggle(
                      'people',
                      'Auto-join compatible games',
                      'Automatically join games that match your preferences',
                      true,
                    ),
                    _staticToggle(
                      'building',
                      'Use location for recommendations',
                      'Find games near your current location',
                      true,
                    ),
                    _staticToggle(
                      'clock',
                      'Flexible timing',
                      'Show games with flexible start times',
                      false,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _staticToggle(String icon, String title, String subtitle, bool on) {
    return Builder(
      builder: (context) => DabblerInputRow(
        leading: DabblerIcon(
          icon,
          size: DabblerSizing.iconMd,
          color: DabblerColors.of(context).textSecondary,
        ),
        title: title,
        subtitle: subtitle,
        trailing: DabblerToggle(checked: on, onChanged: (_) {}),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.showCreateGame, required this.onCreateGame});

  final bool showCreateGame;
  final VoidCallback onCreateGame;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return DabblerSurface(
      padding: const EdgeInsetsDirectional.all(DabblerSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DabblerIcon(
                'game',
                size: DabblerSizing.iconMd,
                color: colors.brandPrimary,
              ),
              const SizedBox(width: DabblerSpacing.space4),
              Expanded(
                child: DabblerText('Sports & Games', style: DabblerType.title3),
              ),
              if (showCreateGame) ...[
                const SizedBox(width: DabblerSpacing.space4),
                DabblerButton(
                  label: 'Create game',
                  icon: 'add-circle',
                  size: DabblerButtonSize.small,
                  onPressed: onCreateGame,
                ),
              ],
            ],
          ),
          const SizedBox(height: DabblerSpacing.space3),
          DabblerText(
            'Customize your sports preferences and skill levels to get the best game recommendations.',
            style: DabblerType.subheadline,
            tone: DabblerTextTone.secondary,
          ),
        ],
      ),
    );
  }
}

class _SportItem extends StatelessWidget {
  const _SportItem({
    required this.sportKey,
    required this.preference,
    required this.expanded,
    required this.positions,
    required this.onToggleExpanded,
    required this.onEnabledChanged,
    required this.onSkillLevel,
    required this.onPosition,
  });

  final String sportKey;
  final SportPreference preference;
  final bool expanded;
  final List<String> positions;
  final VoidCallback onToggleExpanded;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<SkillLevel> onSkillLevel;
  final ValueChanged<String?> onPosition;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final enabled = preference.isEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerInputRow(
          // The sport emoji is replaced by the DS sport glyph.
          leading: DabblerSportIcon.fromKey(
            sportKey.replaceAll('_', '-'),
            color: enabled ? colors.textPrimary : colors.textTertiary,
          ),
          title: preference.name,
          subtitle: enabled ? preference.skillLevel.displayName : 'Disabled',
          trailing: DabblerToggle(
            checked: enabled,
            onChanged: onEnabledChanged,
          ),
          // Was an ExpansionTile: tapping the row opens the editor.
          onTap: onToggleExpanded,
        ),
        if (expanded && enabled)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space5,
              DabblerSpacing.space4,
              DabblerSpacing.space5,
              DabblerSpacing.space4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DabblerText(
                  'Skill Level',
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                ),
                const SizedBox(height: DabblerSpacing.space3),
                Wrap(
                  spacing: DabblerSpacing.space3,
                  runSpacing: DabblerSpacing.space3,
                  children: [
                    for (final level in SkillLevel.values)
                      DabblerChip(
                        label: level.displayName,
                        selected: preference.skillLevel == level,
                        onTap: () => onSkillLevel(level),
                      ),
                  ],
                ),
                if (preference.preferredPosition != null &&
                    positions.isNotEmpty) ...[
                  const SizedBox(height: DabblerSpacing.space5),
                  DabblerSelect<String>(
                    label: 'Preferred Position',
                    value: preference.preferredPosition,
                    options: [
                      for (final p in positions)
                        DabblerSelectOption<String>(value: p, label: p),
                    ],
                    onChanged: onPosition,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
