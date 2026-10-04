import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_step_frame.dart'
    show OnboardingSportGlyph;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The Profiles design's sport picker: a section label ("My sports") with the
/// Manage link and a rail of sport chips, each drawn in its sport's accent;
/// the selected sport scopes the bento.
class OwnProfileSportPicker extends StatelessWidget {
  const OwnProfileSportPicker({
    super.key,
    required this.sports,
    required this.selectedId,
    required this.primaryId,
    required this.onSelect,
    this.onManage,
    this.title,
  });

  final List<Sport> sports;

  /// The selected sport id; null is "all sports".
  final String? selectedId;
  final String? primaryId;
  final ValueChanged<String?> onSelect;

  /// The Manage link; null hides it (another user's profile).
  final VoidCallback? onManage;

  /// The section label; defaults to "My sports".
  final String? title;

  /// The kebab-case key the DS accent table reads.
  static String sportKeyOf(Sport s) =>
      s.sportKey ?? s.nameEn.toLowerCase().replaceAll(' ', '_');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DabblerColors colors = DabblerColors.of(context);
    final TextDirection direction = Directionality.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DabblerSpacing.space6,
          ),
          child: DabblerSection(
            title: title ?? l10n.profile_section_my_sports,
            style: DabblerSectionStyle.label,
            action: onManage == null
                ? null
                : DabblerTextLink(
                    label: l10n.profile_btn_manage,
                    underline: false,
                    style: DabblerType.footnote
                        .resolveForDirection(direction)
                        .copyWith(fontWeight: DabblerType.semibold),
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
          DabblerChipRail(
            size: DabblerChipSize.large,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: DabblerSpacing.space6,
            ),
            items: <DabblerChipRailItem>[
              DabblerChipRailItem(
                label: l10n.profile_sport_picker_all,
                selected: selectedId == null,
                onTap: () => onSelect(null),
                leadingIcon: DabblerIcon(
                  'activity',
                  weight: selectedId == null
                      ? DabblerIconWeight.bold
                      : DabblerIconWeight.linear,
                  size: DabblerSizing.iconSm,
                ),
              ),
              for (final Sport s in sports)
                DabblerChipRailItem(
                  label: s.nameEn,
                  selected: selectedId == s.id,
                  accent: DabblerSportAccent.of(sportKeyOf(s)),
                  dot: s.id == primaryId,
                  onTap: () => onSelect(s.id),
                  leadingIcon: OnboardingSportGlyph(
                    sport: s,
                    selected: selectedId == s.id,
                    size: DabblerSizing.iconSm,
                    color: selectedId == s.id
                        ? colors.onBrand
                        : colors.textSecondary,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
