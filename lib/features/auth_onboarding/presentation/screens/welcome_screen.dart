import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart'
    show routerRefreshNotifier;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The welcome that closes onboarding (and follows adding a persona): who the
/// user is, the persona's principle, and what to remember — the "Complete"
/// frame of `Auth and Onboarding.dc.html`.
class WelcomeScreen extends StatefulWidget {
  final String displayName;
  final String personaType; // player, organiser, host, socialiser
  final bool
  isFirstTime; // true = onboarding, false = returning user or add persona
  final bool isConversion; // true = converting from one persona type to another

  /// The DS key of the user's primary sport; its artwork fills the page when
  /// the design system has one.
  final String? primarySportKey;

  const WelcomeScreen({
    super.key,
    required this.displayName,
    required this.personaType,
    this.isFirstTime = true,
    this.isConversion = false,
    this.primarySportKey,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    // The page's artwork is the primary sport's bundled background; the
    // registry needs the bundled PNGs registered once (idempotent).
    DabblerSportBackgroundRegistry.registerConventionalMainArtwork(
      DabblerSportBackgroundRegistry.mainPopulated,
      DabblerSportBackgroundRegistry.assetPackage,
    );
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
    final sport = widget.primarySportKey == null
        ? null
        : DabblerSport.fromKey(widget.primarySportKey!);
    final Widget? background = sport == null
        ? null
        : DabblerSportBackground.maybe(sport);

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
            titleStyle: DabblerType.displayScreen,
            bodyGap: DabblerSpacing.space8,
            primaryLabel: l10n.auth_welcome_continue,
            onPrimary: _continue,
            footerBottomPadding: DabblerSpacing.space9,
          );
        }

        return DabblerFlowPage(
          background: background,
          spreadChildren: true,
          bodyTopPadding: DabblerSpacing.space8,
          footerBottomPadding: DabblerSpacing.space9,
          primaryLabel: persona.cta,
          onPrimary: _continue,
          leading: _header(
            persona,
            name,
            avatarUrl,
            onArtwork: background != null,
          ),
          content: [
            DabblerCard(
              variant: DabblerCardVariant.white,
              padding: DabblerInsets.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DabblerText(
                    persona.headline,
                    style: DabblerType.displayWelcome,
                  ),
                  const DabblerGap.v(DabblerSpacing.space4),
                  DabblerText(
                    persona.principle,
                    style: DabblerType.leadLarge,
                    weight: DabblerTextWeight.semibold,
                  ),
                ],
              ),
            ),
            DabblerCard(
              variant: DabblerCardVariant.white,
              padding: DabblerInsets.card,
              child: DabblerIconList(
                title: persona.listTitle,
                items: persona.items,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Avatar, name and persona badge.
  Widget _header(
    _PersonaContent persona,
    String name,
    String? avatarUrl, {
    required bool onArtwork,
  }) {
    return Row(
      children: [
        DabblerAvatar(
          size: DabblerAvatarSize.lg,
          seed: name,
          imageUrl: avatarUrl,
        ),
        const DabblerGap.h(DabblerSpacing.space5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DabblerText(
                name,
                style: DabblerType.rowTitle,
                weight: DabblerTextWeight.semibold,
                tone: onArtwork
                    ? DabblerTextTone.onBrand
                    : DabblerTextTone.primary,
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
