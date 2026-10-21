import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart'
    show routerRefreshNotifier;
import 'package:dabbler/features/auth_onboarding/presentation/welcome_sport_poster.dart';
import 'package:dabbler/features/location/location_intro/location_intro.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// Test seam: how the saved primary sport is read when the route carried
  /// none (default: the signed-in user's profile).
  @visibleForTesting
  final WelcomeSavedSportLoader? savedSportLoader;

  const WelcomeScreen({
    super.key,
    required this.displayName,
    required this.personaType,
    this.isFirstTime = true,
    this.isConversion = false,
    this.primarySportKey,
    this.savedSportLoader,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final Future<Map<String, dynamic>?> _profileFuture;

  /// The primary sport whose poster fills the page. Null until it is known, so
  /// the normal background shows meanwhile and a wrong sport never flashes.
  String? _posterSportKey;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthService().getUserProfile(
      fields: const ['avatar_url', 'display_name'],
    );
    _resolvePosterSport();
    // KAN-597: a shared-link entry (including a first sign-up) does not stop on Welcome; it continues straight to the
    // item once this screen is up.
    if (routerRefreshNotifier.hasPendingDeepLink) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _continue();
      });
    }
  }

  /// The sign-up's selected sport arrives with the route; otherwise (Welcome
  /// Back, or extras missing) the saved primary sport is read from the
  /// profile. Adding a persona keeps its previous look.
  void _resolvePosterSport() {
    final fromRoute = welcomePosterAsset(widget.primarySportKey) == null
        ? null
        : widget.primarySportKey;
    if (fromRoute != null) {
      _posterSportKey = fromRoute;
      return;
    }
    if (widget.isConversion) return;
    final load = widget.savedSportLoader ?? loadSavedPrimarySportKey;
    load()
        .then((key) {
          if (!mounted || welcomePosterAsset(key) == null) return;
          setState(() => _posterSportKey = key);
        })
        .catchError((_) {});
  }

  /// The active persona's existing principle line, or null for an unknown
  /// persona (then the card shows the greeting alone).
  String? _returningQuote(AppLocalizations l) {
    switch (widget.personaType.trim().toLowerCase()) {
      case 'socialiser':
        return l.persona_socialiser_principle;
      case 'player':
        return l.persona_player_principle;
      case 'organiser':
        return l.persona_organiser_principle;
      case 'host':
        return l.persona_host_principle;
      default:
        return null;
    }
  }

  /// First word of the display name — presentation only.
  static String _firstName(String name) {
    final trimmed = name.trim();
    final space = trimmed.indexOf(RegExp(r'\s'));
    return space < 0 ? trimmed : trimmed.substring(0, space);
  }

  bool _continuing = false;

  /// Continue from Welcome / Welcome Back: the location introduction first
  /// (once per user on this device, never when the permission is already
  /// granted; the check reads the permission without requesting it), else Home.
  Future<void> _continue() async {
    if (_continuing) return;
    _continuing = true;
    // Decide first, while this screen is still the current route; then drop
    // the welcome guard and navigate in one step, so no router refresh sends
    // the user Home in between.
    final container = ProviderScope.containerOf(context, listen: false);
    // KAN-597: someone who came in through a shared link goes straight to the item: no location introduction.
    if (routerRefreshNotifier.hasPendingDeepLink) {
      routerRefreshNotifier.clearPostLoginWelcome(notify: false);
      context.go(RoutePaths.home);
      return;
    }
    final show = await shouldShowLocationIntro(
      userId: container.read(locationIntroUserIdProvider),
      gateway: container.read(locationPermissionGatewayProvider),
      store: container.read(locationIntroStoreProvider),
      hasManualSetup: () =>
          deviceHasManualLocation(container.read(locationIntroUserIdProvider)),
    );
    if (!mounted) return;
    routerRefreshNotifier.clearPostLoginWelcome(notify: false);
    context.go(show ? RoutePaths.locationIntro : RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final persona = _personaContent(widget.personaType);
    final returning = !widget.isFirstTime && !widget.isConversion;
    final Widget? background = welcomePosterBackground(_posterSportKey);

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
          final quote = _returningQuote(l10n);
          // Avatar at the top (start side), the greeting and the persona's
          // line in one white card under it, Continue at the bottom; the
          // poster (when there is one) fills the rest.
          return DabblerFlowPage(
            leading: Align(
              alignment: AlignmentDirectional.centerStart,
              child: DabblerAvatar(
                seed: name,
                imageUrl: avatarUrl,
                size: DabblerAvatarSize.xl,
              ),
            ),
            bodyTopPadding: DabblerSpacing.space6,
            content: <Widget>[
              DabblerCard(
                variant: DabblerCardVariant.white,
                borderOutside: true,
                radius: DabblerRadius.xl,
                padding: DabblerInsets.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // The frame greets by first name only.
                    DabblerText(
                      l10n.auth_welcome_back_title(_firstName(name)),
                      style: DabblerType.displayScreen,
                    ),
                    if (quote != null) ...<Widget>[
                      const DabblerGap.v(DabblerSpacing.space4),
                      DabblerText(
                        quote,
                        style: DabblerType.leadLarge,
                        weight: DabblerTextWeight.semibold,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            background: background,
            primaryLabel: l10n.auth_welcome_continue,
            onPrimary: _continue,
            footerBottomPadding: DabblerSpacing.space9,
          );
        }

        return DabblerFlowPage(
          background: background,
          spreadChildren: true,
          bodyTopPadding: DabblerSpacing.space8,
          bodyBottomPadding: DabblerSpacing.space8,
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
              borderOutside: true,
              radius: DabblerRadius.xl,
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
              borderOutside: true,
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
    final row = Row(
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
                tone: DabblerTextTone.primary,
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
    // Over a poster the header sits on a white card (like the cards below it)
    // so the name stays legible on every artwork.
    if (!onArtwork) return row;
    return DabblerCard(
      variant: DabblerCardVariant.white,
      borderOutside: true,
      radius: DabblerRadius.xl,
      padding: DabblerInsets.card,
      child: row,
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
