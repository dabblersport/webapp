import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart'
    show routerRefreshNotifier;
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
            title: l10n.auth_welcome_back_title(name),
            titleStyle: DabblerType.largeTitle,
            primaryLabel: l10n.auth_welcome_continue,
            onPrimary: _continue,
            footerBottomPadding: DabblerSpacing.space9,
          );
        }

        return DabblerFlowPage(
          spreadChildren: true,
          footerBottomPadding: DabblerSpacing.space9,
          primaryLabel: persona.cta,
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
                        label: persona.name,
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
                  DabblerText(persona.headline, style: DabblerType.largeTitle),
                  const DabblerGap.v(DabblerSpacing.space4),
                  DabblerText(
                    persona.principle,
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
                    persona.listTitle.toUpperCase(),
                    style: DabblerType.footnote,
                    weight: DabblerTextWeight.semibold,
                    tone: DabblerTextTone.secondary,
                  ),
                  for (final String line in persona.items) ...<Widget>[
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

  _PersonaContent _personaContent(String persona) {
    final l = AppLocalizations.of(context);
    switch (persona.toLowerCase()) {
      case 'organiser':
        return _PersonaContent(
          icon: 'calendar',
          name: l.persona_organiser_name,
          headline: l.persona_organiser_headline,
          principle: l.persona_organiser_principle,
          listTitle: l.persona_organiser_list_title,
          items: [
            l.persona_organiser_item1,
            l.persona_organiser_item2,
            l.persona_organiser_item3,
          ],
          cta: l.persona_organiser_cta,
        );
      case 'host':
        return _PersonaContent(
          icon: 'location',
          name: l.persona_host_name,
          headline: l.persona_host_headline,
          principle: l.persona_host_principle,
          listTitle: l.persona_host_list_title,
          items: [
            l.persona_host_item1,
            l.persona_host_item2,
            l.persona_host_item3,
          ],
          cta: l.persona_host_cta,
        );
      case 'socialiser':
        return _PersonaContent(
          icon: 'people',
          name: l.persona_socialiser_name,
          headline: l.persona_socialiser_headline,
          principle: l.persona_socialiser_principle,
          listTitle: l.persona_socialiser_list_title,
          items: [
            l.persona_socialiser_item1,
            l.persona_socialiser_item2,
            l.persona_socialiser_item3,
          ],
          cta: l.persona_socialiser_cta,
        );
      case 'player':
      default:
        return _PersonaContent(
          icon: 'game',
          name: l.persona_player_name,
          headline: l.persona_player_headline,
          principle: l.persona_player_principle,
          listTitle: l.persona_player_list_title,
          items: [
            l.persona_player_item1,
            l.persona_player_item2,
            l.persona_player_item3,
          ],
          cta: l.persona_player_cta,
        );
    }
  }
}

/// The persona-specific words of the welcome frame.
class _PersonaContent {
  const _PersonaContent({
    required this.icon,
    required this.name,
    required this.headline,
    required this.principle,
    required this.listTitle,
    required this.items,
    required this.cta,
  });

  final String icon;
  final String name;
  final String headline;
  final String principle;
  final String listTitle;
  final List<String> items;
  final String cta;
}
