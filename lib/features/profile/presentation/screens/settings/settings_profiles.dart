import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/settings_sheets.dart';
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

  PersonaAvailability? organiserAvailability() {
    final personaState = ref.read(personaServiceProvider);
    if (personaState.isLoading || personaState.isAtProfileLimit) return null;
    for (final a in personaState.availablePersonas) {
      if (a.targetPersona == PersonaType.organiser &&
          a.actionType == PersonaActionType.add) {
        return a;
      }
    }
    return null;
  }

  /// The organiser row opens the design's info sheet before the setup flow.
  void openOrganiser(PersonaAvailability availability) =>
      showSettingsOrganiserSheet(
        context,
        () => _startPersonaFlow(availability),
      );

  /// The Profiles group: the design's single Become-an-organiser row, then any
  /// other persona the user can still add or convert to.
  Widget buildProfileSection(BuildContext context) {
    final personaState = ref.watch(personaServiceProvider);
    if (personaState.isLoading) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final isAtLimit = personaState.isAtProfileLimit;
    final availablePersonas = isAtLimit
        ? <PersonaAvailability>[]
        : personaState.availablePersonas;
    final organiser = organiserAvailability();
    final others = [
      for (final a in availablePersonas)
        if (a.targetPersona != organiser?.targetPersona ||
            a.actionType != organiser?.actionType)
          a,
    ];

    if (organiser == null && others.isEmpty && !isAtLimit) {
      return const SizedBox.shrink();
    }

    return DabblerRowGroup(
      header: l10n.settings_section_profiles,
      children: [
        if (isAtLimit) _buildExistingProfilesList(context),
        if (organiser != null)
          DabblerInputRow(
            flat: true,
            showDivider: false,
            onTap: () => openOrganiser(organiser),
            leading: leadingIcon('calendar-edit'),
            title: l10n.settings_organiser_title,
            subtitle: l10n.settings_organiser_subtitle,
            trailing: const DabblerChevron(circled: true),
          ),
        for (final availability in others)
          _buildPersonaItem(context, availability),
      ],
    );
  }

  Widget _buildExistingProfilesList(BuildContext context) {
    final availableProfilesAsync = ref.watch(availableProfilesProvider);
    final activeProfileType = ref.watch(activeProfileTypeProvider);
    final colors = DabblerColors.of(context);

    return availableProfilesAsync.when(
      data: (profiles) {
        if (profiles.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final profile in profiles)
              Builder(
                builder: (context) {
                  final effectiveType =
                      profile.personaType ?? profile.profileType;
                  final isActive =
                      effectiveType?.toLowerCase() ==
                      activeProfileType?.toLowerCase();
                  final name = profile.getDisplayName().isNotEmpty
                      ? profile.getDisplayName()
                      : 'Profile';
                  return DabblerInputRow(
                    flat: true,
                    showDivider: false,
                    onTap: () => _switchProfile(isActive, effectiveType),
                    leading: DabblerAvatar(
                      seed: name,
                      imageUrl: profile.avatarUrl,
                      size: DabblerAvatarSize.sm,
                    ),
                    title: name,
                    subtitle: (effectiveType ?? 'player').toUpperCase(),
                    trailing: isActive
                        ? DabblerIcon(
                            'tick-circle',
                            size: DabblerSizing.iconMd,
                            color: colors.brandPrimary,
                          )
                        : const DabblerChevron(circled: true),
                  );
                },
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(DabblerSpacing.space5),
        child: Center(child: DabblerSpinner()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _switchProfile(bool isActive, String? effectiveType) async {
    if (isActive || effectiveType == null) return;
    // Switch active profile in the database
    final switched = await ref
        .read(personaServiceProvider.notifier)
        .switchActiveProfile(effectiveType);

    if (!switched) {
      if (mounted) {
        final errorMsg =
            ref.read(personaServiceProvider).errorMessage ??
            AppLocalizations.of(context).profile_error_switch_profile_failed;
        toast(errorMsg);
      }
      return;
    }

    // Update local state and persist
    ref.read(activeProfileTypeProvider.notifier).state = effectiveType;
    persistActiveProfileType(effectiveType);

    // Clear cached profile so the profile screen loads fresh data
    final userId = AuthService().getCurrentUser()?.id;
    if (userId != null) {
      final localDS = ref.read(profileLocalDataSourceProvider);
      await localDS.clearUserCache(userId);
    }

    if (mounted) context.go('/profile');
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
