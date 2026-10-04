import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_step_frame.dart'
    show OnboardingSportGlyph;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The Profiles design's sport picker: a titled header with the edit action
/// and a horizontal rail of sport chips; the selected sport scopes the bento.
class OwnProfileSportPicker extends StatelessWidget {
  const OwnProfileSportPicker({
    super.key,
    required this.sports,
    required this.selectedId,
    required this.primaryId,
    required this.onSelect,
    this.onManage,
  });

  final List<Sport> sports;

  /// The selected sport id; null is "all sports".
  final String? selectedId;
  final String? primaryId;
  final ValueChanged<String?> onSelect;

  /// The edit action; null hides it (another user's profile).
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DabblerColors colors = DabblerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DabblerSpacing.space6,
          ),
          child: DabblerSection(
            title: l10n.profile_section_sports,
            style: DabblerSectionStyle.label,
            action: onManage == null
                ? null
                : DabblerButton.icon(
                    icon: 'edit',
                    tone: DabblerButtonTone.neutral,
                    size: DabblerButtonSize.small,
                    semanticLabel: l10n.profile_btn_edit,
                    onPressed: onManage,
                  ),
          ),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        if (sports.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DabblerSpacing.space6,
            ),
            child: DabblerText(
              l10n.profile_empty_no_sports,
              style: DabblerType.footnote,
              tone: DabblerTextTone.secondary,
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: DabblerSpacing.space6,
            ),
            child: Row(
              children: <Widget>[
                DabblerChip(
                  label: l10n.user_profile_stat_sports,
                  selected: selectedId == null,
                  onTap: () => onSelect(null),
                  leadingIcon: const DabblerIcon(
                    'activity',
                    size: DabblerSizing.iconSm,
                  ),
                ),
                for (final Sport s in sports) ...<Widget>[
                  const DabblerGap.h(DabblerSpacing.space2),
                  DabblerChip(
                    label: s.nameEn,
                    selected: selectedId == s.id,
                    dot: s.id == primaryId,
                    onTap: () => onSelect(s.id),
                    leadingIcon: OnboardingSportGlyph(
                      sport: s,
                      selected: selectedId == s.id,
                      size: DabblerSizing.iconSm,
                      color: selectedId == s.id
                          ? colors.onBrand
                          : colors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
