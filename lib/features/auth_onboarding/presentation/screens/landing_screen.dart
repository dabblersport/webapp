import 'dart:async';

import 'package:dabbler/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// One person on the welcome carousel — a name, the role they play on Dabbler,
/// and the two lines that say what they want from it.
class _Vignette {
  const _Vignette({
    required this.seed,
    required this.name,
    required this.role,
    required this.quote,
    required this.want,
  });

  final String seed;
  final String name;
  final String role;
  final String quote;
  final String want;
}

const List<_Vignette> _kVignettes = <_Vignette>[
  _Vignette(
    seed: 'Marcus Adeyemi',
    name: 'Marcus',
    role: 'Organiser',
    quote:
        'Half the group chat’s flaky. The other half changes their mind by Friday.',
    want:
        'I just want one place to organise a 5-a-side and stop chasing replies.',
  ),
  _Vignette(
    seed: 'Aisha Khan',
    name: 'Aisha',
    role: 'Player',
    quote: 'New city, decent left foot, nobody to pass to.',
    want: 'I want a game this week, not a group chat about a game.',
  ),
  _Vignette(
    seed: 'Priya Nair',
    name: 'Priya',
    role: 'Socialiser',
    quote: 'I follow more padel than I’ve ever actually played.',
    want: 'Show me who’s playing near me and I’ll find my way in.',
  ),
  _Vignette(
    seed: 'The Sevens Stadium',
    name: 'The Sevens',
    role: 'Host',
    quote: 'Three pitches free at 9pm and nobody knows about it.',
    want: 'Put my courts in front of players already looking for one.',
  ),
];

/// The app welcome: a carousel of the people Dabbler is for, the one-line
/// pitch, Continue, and the region and language chips.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(DabblerMotion.autoAdvanceHero, (_) {
      if (mounted) setState(() => _index = (_index + 1) % _kVignettes.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final _Vignette v = _kVignettes[_index];

    return DabblerPage(
      maxContentWidth: DabblerPage.readableWidth,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.only(
                start: DabblerSpacing.space8,
                top: DabblerSpacing.space4,
                end: DabblerSpacing.space8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DabblerWordmark(color: DabblerColors.of(context).brandPrimary),
                  const DabblerGap.v(DabblerSpacing.space9),
                  Row(
                    children: <Widget>[
                      DabblerAvatar(seed: v.seed, size: DabblerAvatarSize.md),
                      const DabblerGap.h(DabblerSpacing.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            DabblerText(
                              v.name,
                              style: DabblerType.body,
                              weight: DabblerTextWeight.medium,
                            ),
                            const DabblerGap.v(DabblerSpacing.space1),
                            DabblerBadge(
                              label: v.role.toUpperCase(),
                              outlined: true,
                              fill: DabblerColors.of(context).surfaceSunken,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const DabblerGap.v(DabblerSpacing.space8),
                  DabblerText(v.quote, style: DabblerType.largeTitle),
                  const DabblerGap.v(DabblerSpacing.space6),
                  DabblerText(
                    v.want,
                    style: DabblerType.callout,
                    weight: DabblerTextWeight.regular,
                    tone: DabblerTextTone.secondary,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space8,
              DabblerSpacing.space6,
              DabblerSpacing.space8,
              DabblerSpacing.space9,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DabblerPageDots(
                    count: _kVignettes.length,
                    index: _index,
                    onSelected: (int i) => setState(() => _index = i),
                  ),
                ),
                const DabblerGap.v(DabblerSpacing.space5),
                DabblerText(
                  l10n.landing_tagline,
                  style: DabblerType.subheadline,
                  tone: DabblerTextTone.secondary,
                ),
                const DabblerGap.v(DabblerSpacing.space5),
                authIdentify(
                  'landing-continue',
                  DabblerButton(
                    label: l10n.landing_continue,
                    size: DabblerButtonSize.full,
                    fullWidth: true,
                    onPressed: () => context.go(RoutePaths.authWelcome),
                  ),
                ),
                const DabblerGap.v(DabblerSpacing.space5),
                const AuthLocaleChips(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
