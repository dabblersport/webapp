import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The Settings root's Profiles group and the persona flows behind it: the
/// design's Become-an-organiser row, other available personas, and profile
/// switching at the profile limit.
mixin SettingsProfilesMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Widget leadingIcon(String name, {Color? color}) {
    final colors = DabblerColors.of(context);
    return DabblerIcon(
      name,
      size: DabblerSizing.iconMd,
      color: color ?? colors.textPrimary,
    );
  }

  /// The Profiles group: edit profile, then any persona the user can convert
  /// to. Adding another profile is not offered.
  Widget buildProfileSection(BuildContext context) {
    final personaState = ref.watch(personaServiceProvider);
    if (personaState.isLoading) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final isAtLimit = personaState.isAtProfileLimit;
    final availablePersonas = isAtLimit
        ? <PersonaAvailability>[]
        : personaState.availablePersonas;
    final others = [
      for (final a in availablePersonas)
        if (a.actionType == PersonaActionType.convert) a,
    ];

    return DabblerRowGroup(
      header: l10n.settings_section_profiles,
      children: [
        DabblerInputRow(
          flat: true,
          showDivider: false,
          onTap: () => context.push('/profile/edit'),
          leading: leadingIcon('edit'),
          title: l10n.profile_btn_edit,
          subtitle: l10n.settings_item_edit_profile_subtitle,
          trailing: const DabblerChevron(circled: true),
        ),
        for (final availability in others)
          _buildPersonaItem(context, availability),
      ],
    );
  }

  void toast(
    String message, {
    DabblerToastTone tone = DabblerToastTone.neutral,
  }) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: tone));
  }

  Widget _buildPersonaItem(
    BuildContext context,
    PersonaAvailability availability,
  ) {
    final l10n = AppLocalizations.of(context);
    final colors = DabblerColors.of(context);
    final isConversion = availability.actionType == PersonaActionType.convert;

    final String icon = switch (availability.targetPersona) {
      PersonaType.player => 'people',
      PersonaType.organiser => 'calendar-edit',
      PersonaType.host => 'building',
      PersonaType.socialiser => 'message',
      PersonaType.contributor => 'people',
      PersonaType.partner => 'building',
    };

    final title = isConversion
        ? l10n.settings_persona_convert_title(
            availability.targetPersona.displayName,
          )
        : l10n.settings_persona_become_title(
            availability.targetPersona.displayName,
          );

    final subtitle = isConversion
        ? l10n.settings_persona_convert_subtitle(
            availability.convertFrom?.displayName ?? '',
          )
        : availability.targetPersona.description;

    return DabblerInputRow(
      flat: true,
      showDivider: false,
      onTap: () => _startPersonaFlow(availability),
      leading: leadingIcon(
        icon,
        color: isConversion ? colors.accent : colors.textPrimary,
      ),
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConversion) ...[
            DabblerBadge(
              label: l10n.profile_persona_convert_badge.toUpperCase(),
              tone: DabblerBadgeTone.primary,
            ),
            const SizedBox(width: DabblerSpacing.space2),
          ],
          const DabblerChevron(circled: true),
        ],
      ),
    );
  }

  void _startPersonaFlow(PersonaAvailability availability) {
    final personaState = ref.read(personaServiceProvider);

    // Re-check active profile count before navigation
    if (personaState.isAtProfileLimit &&
        availability.actionType == PersonaActionType.add) {
      toast(PersonaRules.profileLimitMessage, tone: DabblerToastTone.error);
      return;
    }

    final primaryProfile = personaState.primaryProfile;

    // Initialize add persona data with shared attributes
    ref
        .read(addPersonaDataProvider.notifier)
        .init(
          targetPersona: availability.targetPersona,
          actionType: availability.actionType,
          convertFrom: availability.convertFrom,
          age: primaryProfile?.age,
          gender: primaryProfile?.gender,
          existingProfileId:
              availability.actionType == PersonaActionType.convert
              ? personaState.activeProfiles
                    .firstWhere(
                      (p) => p.personaType == availability.convertFrom,
                      orElse: () => personaState.activeProfiles.first,
                    )
                    .profileId
              : null,
        );

    if (availability.actionType == PersonaActionType.convert) {
      _showConversionConfirmDialog(availability);
    } else {
      context.push(RoutePaths.addPersonaInterests);
    }
  }

  void _showConversionConfirmDialog(PersonaAvailability availability) {
    final l10n = AppLocalizations.of(context);
    showDabblerDialog<void>(
      context: context,
      builder: (dialogContext) => DabblerDialog(
        onClose: () => Navigator.of(dialogContext).pop(),
        title: l10n.profile_convert_to(availability.targetPersona.displayName),
        description: l10n.settings_persona_convert_confirm_body(
          availability.convertFrom?.displayName ?? '',
          availability.targetPersona.displayName,
        ),
        secondaryAction: DabblerDialogAction(
          label: l10n.profile_btn_cancel,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        primaryAction: DabblerDialogAction(
          label: l10n.profile_btn_continue,
          onPressed: () {
            Navigator.of(dialogContext).pop();
            context.push(RoutePaths.addPersonaInterests);
          },
        ),
      ),
    );
  }
}
