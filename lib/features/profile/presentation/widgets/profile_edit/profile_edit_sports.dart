import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'profile_edit_models.dart';

/// "Interests": one row per sport category, each opening that category's
/// sheet. No design frame (PLAN §2c): DS section + input rows.
class ProfileEditInterestsSection extends StatelessWidget {
  const ProfileEditInterestsSection({
    super.key,
    required this.sportsByCategory,
    required this.selectedIds,
    required this.onOpenCategory,
  });

  final Map<String, List<Sport>> sportsByCategory;
  final Set<String> selectedIds;
  final void Function(String category, List<Sport> sports) onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return DabblerSection(
      title: 'Interests',
      subtitle:
          'Select sports you\'re interested in. Adding a sport here also creates a sport profile for it.',
      action: Text(
        '${selectedIds.length} selected',
        style: DabblerType.footnote
            .resolveForDirection(Directionality.of(context))
            .copyWith(color: colors.textSecondary),
      ),
      children: [
        for (final entry in sportsByCategory.entries)
          _categoryRow(context, colors, entry.key, entry.value),
      ],
    );
  }

  Widget _categoryRow(
    BuildContext context,
    DabblerColors colors,
    String category,
    List<Sport> sports,
  ) {
    final selectedCount = sports
        .where((sport) => selectedIds.contains(sport.id))
        .length;
    return DabblerInputRow(
      title: category,
      subtitle: '$selectedCount of ${sports.length} selected',
      leading: DabblerIcon(
        selectedCount > 0 ? 'tick-circle' : 'heart',
        size: DabblerSizing.iconMd,
        color: selectedCount > 0 ? colors.brandPrimary : colors.textSecondary,
      ),
      trailing: const DabblerChevron(),
      onTap: () => onOpenCategory(category, sports),
    );
  }
}

/// The body of a category's sheet: tap a sport to add it to, or remove it
/// from, the interests. The screen owns the selection; this rebuilds itself
/// after each toggle so the sheet reflects it.
class ProfileEditCategorySportsSheet extends StatefulWidget {
  const ProfileEditCategorySportsSheet({
    super.key,
    required this.sports,
    required this.isSelected,
    required this.isPrimary,
    required this.isPreferred,
    required this.onToggle,
  });

  final List<Sport> sports;
  final bool Function(Sport sport) isSelected;
  final bool Function(Sport sport) isPrimary;
  final bool Function(Sport sport) isPreferred;
  final void Function(Sport sport, bool selected) onToggle;

  @override
  State<ProfileEditCategorySportsSheet> createState() =>
      _ProfileEditCategorySportsSheetState();
}

class _ProfileEditCategorySportsSheetState
    extends State<ProfileEditCategorySportsSheet> {
  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    final selectedCount = widget.sports.where(widget.isSelected).length;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        0,
        DabblerSpacing.space6,
        DabblerSpacing.space8,
      ),
      children: [
        Text(
          '$selectedCount of ${widget.sports.length} selected',
          style: DabblerType.subheadline
              .resolveForDirection(direction)
              .copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: DabblerSpacing.space2),
        Text(
          'Select sports you want to add to your interests in this category.',
          style: DabblerType.footnote
              .resolveForDirection(direction)
              .copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: DabblerSpacing.space5),
        for (final sport in widget.sports) ...[
          _sportRow(context, colors, sport),
          const SizedBox(height: DabblerSpacing.space2),
        ],
      ],
    );
  }

  Widget _sportRow(BuildContext context, DabblerColors colors, Sport sport) {
    final selected = widget.isSelected(sport);
    final tag = widget.isPrimary(sport)
        ? 'Primary sport'
        : (widget.isPreferred(sport) ? 'Preferred sport' : null);
    final row = DabblerInputRow(
      title: ProfileEditSports.label(context, sport),
      subtitle: tag,
      trailing: DabblerIcon(
        selected ? 'tick-circle' : 'add-circle',
        size: DabblerSizing.iconMd,
        color: selected ? colors.brandPrimary : colors.textSecondary,
      ),
      semanticLabel: ProfileEditSports.label(context, sport),
      onTap: () {
        widget.onToggle(sport, !selected);
        setState(() {});
      },
    );
    return selected ? DabblerSurface.selected(child: row) : row;
  }
}

/// "Skill Levels": one select per sport in the interests.
class ProfileEditSkillLevels extends StatelessWidget {
  const ProfileEditSkillLevels({
    super.key,
    required this.entries,
    required this.labelOf,
    required this.onChanged,
  });

  /// Sport key to its current level, in display order.
  final Map<String, SkillLevel> entries;
  final String Function(String sportKey) labelOf;
  final void Function(String sportKey, SkillLevel level) onChanged;

  static const double _selectWidth = 168;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    final options = <DabblerSelectOption<SkillLevel>>[
      for (final level in SkillLevel.values)
        DabblerSelectOption<SkillLevel>(
          value: level,
          label: ProfileEditSports.formatSkillLevel(level),
        ),
    ];
    return DabblerSection(
      title: 'Skill Levels',
      subtitle: 'Set your skill level for each sport in your interests.',
      children: [
        for (final entry in entries.entries)
          Row(
            children: [
              Expanded(
                child: Text(
                  labelOf(entry.key),
                  style: DabblerType.body
                      .resolveForDirection(direction)
                      .copyWith(color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: DabblerSpacing.space4),
              SizedBox(
                width: _selectWidth,
                child: DabblerSelect<SkillLevel>(
                  value: entry.value,
                  options: options,
                  onChanged: (level) => onChanged(entry.key, level),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
