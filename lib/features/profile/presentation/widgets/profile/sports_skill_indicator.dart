import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

TextStyle _text(
  BuildContext context,
  DabblerTypeStyle step,
  Color color, {
  FontWeight? weight,
}) => step
    .resolveForDirection(Directionality.of(context))
    .copyWith(color: color, fontWeight: weight);

class SportsSkillIndicator extends StatelessWidget {
  final String sportName;
  final int skillLevel; // 1-5 scale
  final String skillLabel;
  final Color? primaryColor;
  final bool showLabel;
  final bool isInteractive;
  final ValueChanged<int>? onSkillChanged;

  const SportsSkillIndicator({
    super.key,
    required this.sportName,
    required this.skillLevel,
    required this.skillLabel,
    this.primaryColor,
    this.showLabel = true,
    this.isInteractive = false,
    this.onSkillChanged,
  }) : assert(skillLevel >= 1 && skillLevel <= 5);

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final color = primaryColor ?? colors.brandPrimary;

    return DabblerSurface.card(
      padding: const EdgeInsets.all(DabblerSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DabblerIconTile.tinted(
                DabblerSportIcon.fromKey(_sportKey(sportName), color: color),
                color: color,
              ),
              const SizedBox(width: DabblerSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sportName,
                      style: _text(
                        context,
                        DabblerType.headline,
                        colors.textPrimary,
                      ),
                    ),
                    if (showLabel)
                      Text(
                        skillLabel,
                        style: _text(
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
          const SizedBox(height: DabblerSpacing.space5),
          _buildSkillLevel(context, color, interactive: isInteractive),
        ],
      ),
    );
  }

  Widget _buildSkillLevel(
    BuildContext context,
    Color color, {
    required bool interactive,
  }) {
    final colors = DabblerColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skill Level',
          style: _text(
            context,
            DabblerType.footnote,
            colors.textSecondary,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DabblerSpacing.space2),
        Row(
          children: List.generate(5, (index) {
            final isActive = index < skillLevel;
            final segment = DabblerSurface(
              height: interactive ? 12 : 8,
              radius: DabblerRadius.pill,
              fill: isActive ? color : colors.surfaceSunken,
              borderWidth: 0,
            );
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: index < 4 ? DabblerSpacing.space2 : 0,
                ),
                child: interactive
                    ? GestureDetector(
                        onTap: () => onSkillChanged?.call(index + 1),
                        child: segment,
                      )
                    : segment,
              ),
            );
          }),
        ),
        const SizedBox(height: DabblerSpacing.space2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Beginner',
              style: _text(
                context,
                DabblerType.caption1,
                colors.textTertiary,
              ),
            ),
            Text(
              'Expert',
              style: _text(
                context,
                DabblerType.caption1,
                colors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Display name to the kebab-case DS sport key (`Table Tennis` ->
  /// `table-tennis`); unknown sports fall to the DS sport-icon fallback.
  static String _sportKey(String sport) {
    final key = sport.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
    switch (key) {
      case 'soccer':
        return 'football';
      case 'track':
        return 'running';
      default:
        return key;
    }
  }

  static String getSkillLevelLabel(int level) {
    switch (level) {
      case 1:
        return 'Beginner';
      case 2:
        return 'Novice';
      case 3:
        return 'Intermediate';
      case 4:
        return 'Advanced';
      case 5:
        return 'Expert';
      default:
        return 'Unknown';
    }
  }
}

// Grid layout for multiple sports
class SportsSkillGrid extends StatelessWidget {
  final List<SportSkill> skills;
  final bool isEditable;
  final Function(String sport, int level)? onSkillChanged;

  const SportsSkillGrid({
    super.key,
    required this.skills,
    this.isEditable = false,
    this.onSkillChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DabblerSpacing.space5,
      runSpacing: DabblerSpacing.space5,
      children: [
        for (final skill in skills)
          SizedBox(
            width: 220,
            child: SportsSkillIndicator(
              sportName: skill.sportName,
              skillLevel: skill.level,
              skillLabel: SportsSkillIndicator.getSkillLevelLabel(skill.level),
              primaryColor: skill.color,
              isInteractive: isEditable,
              onSkillChanged: (level) =>
                  onSkillChanged?.call(skill.sportName, level),
            ),
          ),
      ],
    );
  }
}

class SportSkill {
  final String sportName;
  final int level;
  final Color? color;

  const SportSkill({required this.sportName, required this.level, this.color});
}
