import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart'
    show routerRefreshNotifier;
import 'package:dabbler/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatefulWidget {
  final String displayName;
  final String personaType; // player, organiser, host, socialiser
  final bool
  isFirstTime; // true = onboarding, false = returning user or add persona
  final bool isConversion; // true = converting from one persona type to another

  const WelcomeScreen({
    super.key,
    required this.displayName,
    required this.personaType,
    this.isFirstTime = true,
    this.isConversion = false,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthService().getUserProfile(
      fields: const ['avatar_url', 'display_name'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final personaContent = _getPersonaContent(widget.personaType);

    return DabblerPage(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    DabblerSpacing.space8,
                    DabblerSpacing.space6,
                    DabblerSpacing.space8,
                    DabblerSpacing.space6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAvatarRow(context, personaContent),
                      const SizedBox(height: DabblerSpacing.space8),
                      DabblerText(
                        _getWelcomeTitle(),
                        style: DabblerType.largeTitle,
                      ),
                      const SizedBox(height: DabblerSpacing.space4),
                      DabblerText(
                        personaContent.guidanceText,
                        tone: DabblerTextTone.secondary,
                      ),
                      const SizedBox(height: DabblerSpacing.space6),
                      DabblerCard(
                        variant: DabblerCardVariant.white,
                        padding: const EdgeInsets.all(DabblerSpacing.space6),
                        child: DabblerText(
                          personaContent.philosophyStatement,
                          style: DabblerType.title3,
                        ),
                      ),
                      const SizedBox(height: DabblerSpacing.space4),
                      DabblerCard(
                        variant: DabblerCardVariant.white,
                        padding: const EdgeInsets.all(DabblerSpacing.space6),
                        child: _buildReminder(context, personaContent),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  DabblerSpacing.space8,
                  DabblerSpacing.space4,
                  DabblerSpacing.space8,
                  DabblerSpacing.space8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DabblerText(
                      personaContent.finalEmphasis,
                      style: DabblerType.callout,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DabblerSpacing.space5),
                    DabblerButton(
                      label: AppLocalizations.of(
                        context,
                      ).welcome_screen_continue,
                      size: DabblerButtonSize.full,
                      fullWidth: true,
                      onPressed: () {
                        routerRefreshNotifier.clearPostLoginWelcome();
                        context.go(RoutePaths.home);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarRow(BuildContext context, _PersonaContent personaContent) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final avatarUrl = profile?['avatar_url'] as String?;
        final profileName = (profile?['display_name'] as String?)?.trim();
        final resolvedName = (profileName != null && profileName.isNotEmpty)
            ? profileName
            : widget.displayName;

        return Row(
          children: [
            DabblerAvatar(
              size: DabblerAvatarSize.lg,
              seed: resolvedName,
              imageUrl: avatarUrl,
            ),
            const SizedBox(width: DabblerSpacing.space5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DabblerText(
                    resolvedName,
                    style: DabblerType.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DabblerSpacing.space2),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DabblerBadge(label: personaContent.chipLabel),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReminder(BuildContext context, _PersonaContent personaContent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DabblerText(
          AppLocalizations.of(context).welcome_screen_dont_forget,
          style: DabblerType.headline,
        ),
        const SizedBox(height: DabblerSpacing.space2),
        DabblerText(
          personaContent.reminderText,
          style: DabblerType.subheadline,
          tone: DabblerTextTone.secondary,
        ),
      ],
    );
  }

  String _getWelcomeTitle() {
    final l10n = AppLocalizations.of(context);
    if (widget.isConversion) {
      return authStripEmoji(l10n.welcome_screen_title_conversion);
    } else if (widget.isFirstTime) {
      return authStripEmoji(l10n.welcome_screen_title_first_time);
    } else {
      return authStripEmoji(l10n.welcome_screen_title_returning);
    }
  }

  _PersonaContent _getPersonaContent(String persona) {
    final l10n = AppLocalizations.of(context);
    switch (persona.toLowerCase()) {
      case 'player':
        return _PersonaContent(
          chipLabel: l10n.welcome_screen_chip_player,
          guidanceText: l10n.welcome_screen_player_guidance,
          philosophyStatement: l10n.welcome_screen_player_philosophy,
          reminderText: l10n.welcome_screen_player_reminder,
          finalEmphasis: l10n.welcome_screen_player_emphasis,
        );

      case 'organiser':
        return _PersonaContent(
          chipLabel: l10n.welcome_screen_chip_organiser,
          guidanceText: l10n.welcome_screen_organiser_guidance,
          philosophyStatement: l10n.welcome_screen_organiser_philosophy,
          reminderText: l10n.welcome_screen_organiser_reminder,
          finalEmphasis: l10n.welcome_screen_organiser_emphasis,
        );

      case 'host':
        return _PersonaContent(
          chipLabel: l10n.welcome_screen_chip_host,
          guidanceText: l10n.welcome_screen_host_guidance,
          philosophyStatement: l10n.welcome_screen_host_philosophy,
          reminderText: l10n.welcome_screen_host_reminder,
          finalEmphasis: l10n.welcome_screen_host_emphasis,
        );

      case 'socialiser':
        return _PersonaContent(
          chipLabel: l10n.welcome_screen_chip_socialiser,
          guidanceText: l10n.welcome_screen_socialiser_guidance,
          philosophyStatement: l10n.welcome_screen_socialiser_philosophy,
          reminderText: l10n.welcome_screen_socialiser_reminder,
          finalEmphasis: l10n.welcome_screen_socialiser_emphasis,
        );

      default:
        // Fallback to player
        return _PersonaContent(
          chipLabel: l10n.welcome_screen_chip_player,
          guidanceText: l10n.welcome_screen_player_guidance,
          philosophyStatement: l10n.welcome_screen_player_philosophy,
          reminderText: l10n.welcome_screen_player_reminder,
          finalEmphasis: l10n.welcome_screen_player_emphasis,
        );
    }
  }
}

/// Helper class to hold persona-specific content
class _PersonaContent {
  final String chipLabel;
  final String guidanceText;
  final String philosophyStatement;
  final String reminderText;
  final String finalEmphasis;

  _PersonaContent({
    required this.chipLabel,
    required this.guidanceText,
    required this.philosophyStatement,
    required this.reminderText,
    required this.finalEmphasis,
  });
}
