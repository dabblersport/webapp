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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final persona = _persona(l10n, widget.personaType);
    final sport = widget.primarySportKey == null
        ? null
        : DabblerSport.fromKey(widget.primarySportKey!);
    final Widget? background = sport == null
        ? null
        : DabblerSportBackground.maybe(sport);

    return DabblerFlowPage(
      background: background,
      spreadChildren: true,
      bodyTopPadding: DabblerSpacing.space8,
      footerBottomPadding: DabblerSpacing.space9,
      leading: _header(persona, onArtwork: background != null),
      content: [
        DabblerCard(
          variant: DabblerCardVariant.white,
          padding: DabblerInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DabblerText(persona.headline, style: DabblerType.largeTitle),
              const DabblerGap.v(DabblerSpacing.space4),
              DabblerText(
                persona.principle,
                style: DabblerType.headline,
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
      primaryLabel: persona.cta,
      onPrimary: () {
        routerRefreshNotifier.clearPostLoginWelcome();
        context.go(RoutePaths.home);
      },
    );
  }

  /// Avatar, name and persona badge.
  Widget _header(_Persona persona, {required bool onArtwork}) {
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
            const DabblerGap.h(DabblerSpacing.space5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DabblerText(
                    resolvedName,
                    style: DabblerType.headline,
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
                    icon: DabblerIcon(
                      persona.icon,
                      weight: DabblerIconWeight.bold,
                      size: DabblerSizing.iconXs,
                    ),
                    tone: DabblerBadgeTone.defaultTone,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  _Persona _persona(AppLocalizations l10n, String persona) {
    switch (persona.toLowerCase()) {
      case 'organiser':
        return _Persona(
          name: l10n.onb_persona_organiser_name,
          icon: 'calendar',
          headline: l10n.onb_welcome_organiser_headline,
          principle: l10n.onb_welcome_organiser_principle,
          listTitle: l10n.onb_welcome_organiser_list_title,
          items: [
            l10n.onb_welcome_organiser_item1,
            l10n.onb_welcome_organiser_item2,
            l10n.onb_welcome_organiser_item3,
          ],
          cta: l10n.onb_welcome_organiser_cta,
        );
      case 'host':
        return _Persona(
          name: l10n.onb_persona_host_name,
          icon: 'location',
          headline: l10n.onb_welcome_host_headline,
          principle: l10n.onb_welcome_host_principle,
          listTitle: l10n.onb_welcome_host_list_title,
          items: [
            l10n.onb_welcome_host_item1,
            l10n.onb_welcome_host_item2,
            l10n.onb_welcome_host_item3,
          ],
          cta: l10n.onb_welcome_host_cta,
        );
      case 'socialiser':
        return _Persona(
          name: l10n.onb_persona_socialiser_name,
          icon: 'people',
          headline: l10n.onb_welcome_socialiser_headline,
          principle: l10n.onb_welcome_socialiser_principle,
          listTitle: l10n.onb_welcome_socialiser_list_title,
          items: [
            l10n.onb_welcome_socialiser_item1,
            l10n.onb_welcome_socialiser_item2,
            l10n.onb_welcome_socialiser_item3,
          ],
          cta: l10n.onb_welcome_socialiser_cta,
        );
      default:
        return _Persona(
          name: l10n.onb_persona_player_name,
          icon: 'game',
          headline: l10n.onb_welcome_player_headline,
          principle: l10n.onb_welcome_player_principle,
          listTitle: l10n.onb_welcome_player_list_title,
          items: [
            l10n.onb_welcome_player_item1,
            l10n.onb_welcome_player_item2,
            l10n.onb_welcome_player_item3,
          ],
          cta: l10n.onb_welcome_player_cta,
        );
    }
  }
}

/// What the welcome says for one persona.
class _Persona {
  final String name;
  final String icon;
  final String headline;
  final String principle;
  final String listTitle;
  final List<String> items;
  final String cta;

  _Persona({
    required this.name,
    required this.icon,
    required this.headline,
    required this.principle,
    required this.listTitle,
    required this.items,
    required this.cta,
  });
}
