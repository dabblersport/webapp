import 'dart:async';

import 'package:dabbler/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _Testimonial {
  final String name;
  final String vibe;
  final String quote;
  final String highlightWord;

  const _Testimonial({
    required this.name,
    required this.vibe,
    required this.quote,
    required this.highlightWord,
  });
}

const _kTestimonials = [
  _Testimonial(
    name: 'Noor',
    vibe: 'Determined',
    quote:
        "I promised myself I'd play at least twice a week.\n\nBetween work and life, finding a game feels harder than a 90-minute run.",
    highlightWord: 'twice a week',
  ),
  _Testimonial(
    name: 'Marcus',
    vibe: 'Captain',
    quote:
        "Half the group chat's flaky. The other half changes their mind by Friday.\n\nI just want one place to organise a 5-a-side and stop chasing replies.",
    highlightWord: 'one place to organise a 5-a-side',
  ),
  _Testimonial(
    name: 'Aisha',
    vibe: 'Curious',
    quote:
        "I moved to a new city and didn't know a single soul here.\n\nFinding people who shared my vibe shouldn't be this hard.",
    highlightWord: 'Finding people who shared my vibe',
  ),
];

class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  int _idx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(DabblerMotion.autoAdvanceHero, (_) {
      if (mounted) setState(() => _idx = (_idx + 1) % _kTestimonials.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openLanguagePicker() {
    showDabblerSheet<void>(
      context: context,
      detents: const <double>[0.4],
      builder: (ctx) => _LandingLanguagePickerSheet(ref: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final langLabel = locale.languageCode == 'ar' ? 'العربية' : 'English';
    final t = _kTestimonials[_idx];
    final colors = DabblerColors.of(context);

    return DabblerPage(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsetsDirectional.only(
                  start: DabblerSpacing.space8,
                  top: DabblerSpacing.space4,
                  end: DabblerSpacing.space8,
                ),
                child: DabblerWordmark(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: DabblerSpacing.space8,
                    top: DabblerSpacing.space9,
                    end: DabblerSpacing.space8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: DabblerMotion.durationOf(
                          context,
                          DabblerMotion.heroCrossfade,
                        ),
                        child: _UserIdentityRow(key: ValueKey(_idx), t: t),
                      ),
                      const SizedBox(height: DabblerSpacing.space8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: AnimatedSwitcher(
                            duration: DabblerMotion.durationOf(
                              context,
                              DabblerMotion.heroCrossfade,
                            ),
                            child: _QuoteText(key: ValueKey('q$_idx'), t: t),
                          ),
                        ),
                      ),
                      const SizedBox(height: DabblerSpacing.space4),
                      Row(
                        children: List.generate(_kTestimonials.length, (i) {
                          final active = i == _idx;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _idx = i),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: DabblerSpacing.space2,
                              ),
                              child: AnimatedContainer(
                                duration: DabblerMotion.durationOf(
                                  context,
                                  DabblerMotion.scrollTo,
                                ),
                                width: active
                                    ? DabblerSpacing.space8
                                    : DabblerSpacing.space2,
                                height: DabblerSpacing.space2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    DabblerRadius.pill,
                                  ),
                                  color: active
                                      ? colors.brandPrimary
                                      : colors.borderStrong,
                                ),
                              ),
                            ),
                          );
                        }),
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
                  DabblerSpacing.space8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DabblerText(
                      'Dabbler connects players, captains, and venues — so you can stop searching and start playing.',
                      style: DabblerType.subheadline,
                      tone: DabblerTextTone.secondary,
                    ),
                    const SizedBox(height: DabblerSpacing.space5),
                    authIdentify(
                      'landing-continue',
                      DabblerButton(
                        label: AppLocalizations.of(context).landing_continue,
                        size: DabblerButtonSize.full,
                        fullWidth: true,
                        onPressed: () => context.go(RoutePaths.authWelcome),
                      ),
                    ),
                    const SizedBox(height: DabblerSpacing.space4),
                    Center(
                      child: DabblerChip(
                        label: langLabel,
                        leadingIcon: const DabblerIcon('language-square'),
                        onTap: _openLanguagePicker,
                      ),
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
}

class _UserIdentityRow extends StatelessWidget {
  const _UserIdentityRow({super.key, required this.t});
  final _Testimonial t;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DabblerAvatar(seed: t.name, size: DabblerAvatarSize.lg),
        const SizedBox(width: DabblerSpacing.space4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DabblerBadge(label: t.vibe.toUpperCase()),
              const SizedBox(height: DabblerSpacing.space2),
              DabblerText(t.name, style: DabblerType.title2),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuoteText extends StatelessWidget {
  const _QuoteText({super.key, required this.t});
  final _Testimonial t;

  @override
  Widget build(BuildContext context) {
    final parts = t.quote.split(t.highlightWord);
    return DabblerText.rich([
      if (parts.isNotEmpty) DabblerTextSpan(parts[0]),
      DabblerTextSpan(t.highlightWord, tone: DabblerTextTone.brand),
      if (parts.length > 1) DabblerTextSpan(parts[1]),
    ], style: DabblerType.title1);
  }
}

class _LandingLanguagePickerSheet extends StatelessWidget {
  const _LandingLanguagePickerSheet({required this.ref});

  final WidgetRef ref;

  static const _languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'ar', 'name': 'العربية'},
  ];

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(localeProvider);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space4,
        end: DabblerSpacing.space4,
        bottom: DabblerSpacing.space6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space4,
              DabblerSpacing.space2,
              DabblerSpacing.space4,
              DabblerSpacing.space2,
            ),
            child: DabblerText(
              AppLocalizations.of(context).landing_choose_language,
              style: DabblerType.title3,
            ),
          ),
          ..._languages.map((lang) {
            final isSelected = current.languageCode == lang['code'];
            return AuthPickerRow(
              title: lang['name']!,
              selected: isSelected,
              onTap: () {
                ref
                    .read(localeProvider.notifier)
                    .setLocale(Locale(lang['code']!));
                Navigator.of(context).pop();
              },
            );
          }),
        ],
      ),
    );
  }
}
