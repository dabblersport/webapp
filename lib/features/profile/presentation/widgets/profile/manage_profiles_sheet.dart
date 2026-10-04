import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/utils/persona_label.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_header.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The switch-profile sheet body. Shown by [ProfileScreen] inside a
/// [showDabblerSheet] (the sheet owns the title, the handle and the close
/// affordance); pops with the chosen persona type.
class ManageProfilesSheet extends ConsumerStatefulWidget {
  const ManageProfilesSheet({super.key});

  @override
  ConsumerState<ManageProfilesSheet> createState() =>
      _ManageProfilesSheetState();
}

class _ManageProfilesSheetState extends ConsumerState<ManageProfilesSheet> {
  @override
  void initState() {
    super.initState();
    // Fetch user personas when sheet opens
    Future.microtask(() {
      ref.read(personaServiceProvider.notifier).fetchUserPersonas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final availableProfilesAsync = ref.watch(availableProfilesProvider);
    final activeProfileType = ref.watch(activeProfileTypeProvider);
    final personaState = ref.watch(personaServiceProvider);

    return availableProfilesAsync.when(
      data: (profiles) {
        if (profiles.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(DabblerSpacing.space8),
            child: Center(
              child: DabblerText(
                l10n.profile_no_profiles_found,
                style: DabblerType.subheadline,
                tone: DabblerTextTone.secondary,
              ),
            ),
          );
        }

        // Get available persona options (only if not at limit)
        final availablePersonas = personaState.canAddNewProfile
            ? personaState.availablePersonas.where((p) => p.canProceed).toList()
            : <PersonaAvailability>[];

        // Check if at profile limit
        final isAtLimit = personaState.isAtProfileLimit;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Existing profiles section
            ...profiles.map((profile) {
              final effectiveType = profile.personaType ?? profile.profileType;
              final isActive =
                  effectiveType?.toLowerCase() ==
                  activeProfileType?.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(bottom: DabblerSpacing.space2),
                child: _ProfileRow(
                  profile: profile,
                  isActive: isActive,
                  onTap: () {
                    // Pop the sheet and return the persona type
                    // The parent ProfileScreen will handle the full switch
                    Navigator.pop(context, effectiveType);
                  },
                ),
              );
            }),

            // Add persona options section (only if not at limit)
            if (availablePersonas.isNotEmpty && !isAtLimit) ...[
              const DabblerGap.v(DabblerSpacing.space4),
              DabblerSection(
                title: l10n.profile_add_profile,
                children: [
                  for (final availability in availablePersonas)
                    _PersonaOptionTile(
                      availability: availability,
                      onTap: () => _startPersonaFlow(availability),
                    ),
                ],
              ),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(DabblerSpacing.space8),
        child: Center(child: DabblerSpinner()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space8),
        child: Center(
          child: DabblerText(
            l10n.profile_error_loading_profiles,
            style: DabblerType.subheadline,
            tone: DabblerTextTone.error,
          ),
        ),
      ),
    );
  }

  void _startPersonaFlow(PersonaAvailability availability) {
    final personaState = ref.read(personaServiceProvider);

    // Re-check active profile count before navigation
    if (personaState.isAtProfileLimit &&
        availability.actionType == PersonaActionType.add) {
      Navigator.pop(context); // Close the sheet
      DabblerToastProvider.of(context).show(
        const DabblerToastSpec(
          message: PersonaRules.profileLimitMessage,
          tone: DabblerToastTone.error,
        ),
      );
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

    Navigator.pop(context); // Close the sheet first

    // Show confirmation for conversion, otherwise start flow directly
    if (availability.actionType == PersonaActionType.convert) {
      _showConversionConfirmDialog(availability);
    } else {
      // Navigate to first screen of add flow (interests selection)
      context.push(RoutePaths.addPersonaInterests);
    }
  }

  void _showConversionConfirmDialog(PersonaAvailability availability) {
    final l10n = AppLocalizations.of(context);

    showDabblerDialog<void>(
      context: context,
      builder: (dialogContext) => DabblerDialog(
        title: l10n.profile_convert_to(
          personaLabel(context, availability.targetPersona.name),
        ),
        description: l10n.profile_convert_confirm_body(
          personaLabel(context, availability.convertFrom?.name),
          personaLabel(context, availability.targetPersona.name),
        ),
        onClose: () => Navigator.of(dialogContext).pop(),
        secondaryAction: DabblerDialogAction(
          label: l10n.profile_btn_cancel,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        primaryAction: DabblerDialogAction(
          label: l10n.profile_btn_continue,
          onPressed: () {
            Navigator.of(dialogContext).pop();
            // Navigate to first screen of add flow
            context.push(RoutePaths.addPersonaInterests);
          },
        ),
      ),
    );
  }
}

/// Row for displaying an available persona option
class _PersonaOptionTile extends StatelessWidget {
  final PersonaAvailability availability;
  final VoidCallback onTap;

  const _PersonaOptionTile({required this.availability, required this.onTap});

  String get _personaIcon {
    switch (availability.targetPersona) {
      case PersonaType.player:
        return 'user';
      case PersonaType.organiser:
        return 'calendar';
      case PersonaType.host:
        return 'building';
      case PersonaType.socialiser:
        return 'people';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConversion = availability.actionType == PersonaActionType.convert;

    return DabblerInputRow(
      onTap: onTap,
      leading: DabblerIconTile.named(
        _personaIcon,
        tone: isConversion
            ? DabblerIconTileTone.accent
            : DabblerIconTileTone.brand,
      ),
      title: personaLabel(context, availability.targetPersona.name),
      subtitle: availability.targetPersona.description,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConversion) ...[
            DabblerBadge(
              label: AppLocalizations.of(context).profile_persona_convert_badge,
            ),
            const DabblerGap.h(DabblerSpacing.space2),
          ],
          const DabblerChevron(),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final UserProfile profile;
  final bool isActive;
  final VoidCallback onTap;

  const _ProfileRow({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String? persona = profile.personaType ?? profile.profileType;
    final String? username = profile.username;
    return DabblerInputRow(
      onTap: onTap,
      selected: isActive,
      leading: DabblerIconTile.named(
        OwnProfileHeader.personaIcon(persona),
        tone: DabblerIconTileTone.brand,
      ),
      title: personaLabel(context, persona),
      subtitle: username != null && username.isNotEmpty
          ? '\u200E@$username'
          : profile.getDisplayName(),
    );
  }
}
