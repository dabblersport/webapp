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

  void _continue() {
    routerRefreshNotifier.clearPostLoginWelcome();
    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final persona = _personaContent(widget.personaType);
    final returning = !widget.isFirstTime && !widget.isConversion;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final avatarUrl = profile?['avatar_url'] as String?;
        final profileName = (profile?['display_name'] as String?)?.trim();
        final name = (profileName != null && profileName.isNotEmpty)
            ? profileName
            : widget.displayName;

        if (returning) {
          return DabblerFlowPage(
            centered: true,
            leading: Align(
              alignment: AlignmentDirectional.centerStart,
              child: DabblerAvatar(
                seed: name,
                imageUrl: avatarUrl,
                size: DabblerAvatarSize.xl,
              ),
            ),
            title: _title(l10n),
            titleStyle: DabblerType.largeTitle,
            primaryLabel: l10n.welcome_screen_continue,
            onPrimary: _continue,
            footerBottomPadding: DabblerSpacing.space9,
          );
        }

        return DabblerFlowPage(
          spreadChildren: true,
          footerBottomPadding: DabblerSpacing.space9,
          primaryLabel: l10n.welcome_screen_continue,
          onPrimary: _continue,
          leading: Padding(
            padding: const EdgeInsetsDirectional.only(
              top: DabblerSpacing.space4,
            ),
            child: Row(
              children: <Widget>[
                DabblerAvatar(
                  seed: name,
                  imageUrl: avatarUrl,
                  size: DabblerAvatarSize.lg,
                ),
                const DabblerGap.h(DabblerSpacing.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DabblerText(
                        name,
                        style: DabblerType.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const DabblerGap.v(DabblerSpacing.space2),
                      DabblerBadge(
                        label: persona.chipLabel,
                        tone: DabblerBadgeTone.defaultTone,
                        icon: DabblerIcon(
                          persona.icon,
                          weight: DabblerIconWeight.bold,
                          size: DabblerSizing.iconXs,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          content: <Widget>[
            DabblerCard(
              variant: DabblerCardVariant.white,
              padding: DabblerInsets.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DabblerText(_title(l10n), style: DabblerType.largeTitle),
                  const DabblerGap.v(DabblerSpacing.space4),
                  DabblerText(
                    persona.philosophyStatement,
                    style: DabblerType.callout,
                    weight: DabblerTextWeight.semibold,
                  ),
                ],
              ),
            ),
            DabblerCard(
              variant: DabblerCardVariant.white,
              padding: DabblerInsets.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DabblerText(
                    l10n.welcome_screen_dont_forget.toUpperCase(),
                    style: DabblerType.footnote,
                    weight: DabblerTextWeight.semibold,
                    tone: DabblerTextTone.secondary,
                  ),
                  for (final String line in persona.reminderLines) ...<Widget>[
                    const DabblerGap.v(DabblerSpacing.space4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        DabblerIcon(
                          'tick-circle',
                          weight: DabblerIconWeight.bold,
                          size: DabblerSizing.iconSm,
                          color: DabblerColors.of(context).brandPrimary,
                        ),
                        const DabblerGap.h(DabblerSpacing.space3),
                        Expanded(
                          child: DabblerText(
                            line,
                            style: DabblerType.subheadline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _title(AppLocalizations l10n) {
    if (widget.isConversion) {
      return authStripEmoji(l10n.welcome_screen_title_conversion);
    } else if (widget.isFirstTime) {
      return authStripEmoji(l10n.welcome_screen_title_first_time);
    } else {
      return authStripEmoji(l10n.welcome_screen_title_returning);
    }
  }

  _PersonaContent _personaContent(String persona) {
    final l10n = AppLocalizations.of(context);
    switch (persona.toLowerCase()) {
      case 'organiser':
        return _PersonaContent(
          icon: 'calendar',
          chipLabel: l10n.welcome_screen_chip_organiser,
          philosophyStatement: l10n.welcome_screen_organiser_philosophy,
          reminderText: l10n.welcome_screen_organiser_reminder,
        );
      case 'host':
        return _PersonaContent(
          icon: 'location',
          chipLabel: l10n.welcome_screen_chip_host,
          philosophyStatement: l10n.welcome_screen_host_philosophy,
          reminderText: l10n.welcome_screen_host_reminder,
        );
      case 'socialiser':
        return _PersonaContent(
          icon: 'people',
          chipLabel: l10n.welcome_screen_chip_socialiser,
          philosophyStatement: l10n.welcome_screen_socialiser_philosophy,
          reminderText: l10n.welcome_screen_socialiser_reminder,
        );
      case 'player':
      default:
        return _PersonaContent(
          icon: 'game',
          chipLabel: l10n.welcome_screen_chip_player,
          philosophyStatement: l10n.welcome_screen_player_philosophy,
          reminderText: l10n.welcome_screen_player_reminder,
        );
    }
  }
}

/// The persona-specific words of the welcome frame.
class _PersonaContent {
  const _PersonaContent({
    required this.icon,
    required this.chipLabel,
    required this.philosophyStatement,
    required this.reminderText,
  });

  final String icon;
  final String chipLabel;
  final String philosophyStatement;
  final String reminderText;

  List<String> get reminderLines => reminderText
      .split('\n')
      .map((String l) => l.trim())
      .where((String l) => l.isNotEmpty)
      .toList();
}
