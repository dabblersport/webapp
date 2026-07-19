import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/providers.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_widgets.dart';

const _kTestimonials = [
  _Testimonial(
    name: 'Noor',
    vibe: 'Determined',
    initial: 'N',
    gradientFrom: Color(0xFF7328CE),
    gradientTo: Color(0xFFFF3376),
    accentColor: Color(0xFF7328CE),
    sportIcon: Icons.sports_tennis,
    quote:
        "I promised myself I'd play at least twice a week.\n\nBetween work and life, finding a game feels harder than a 90-minute run.",
    highlightWord: 'twice a week',
    highlightColor: Color(0xFFFF3376),
  ),
  _Testimonial(
    name: 'Marcus',
    vibe: 'Captain',
    initial: 'M',
    gradientFrom: Color(0xFF00C853),
    gradientTo: Color(0xFF00B0FF),
    accentColor: Color(0xFF00C853),
    sportIcon: Icons.sports_soccer,
    quote:
        "Half the group chat's flaky. The other half changes their mind by Friday.\n\nI just want one place to organise a 5-a-side and stop chasing replies.",
    highlightWord: 'one place to organise a 5-a-side',
    highlightColor: Color(0xFF00C853),
  ),
  _Testimonial(
    name: 'Aisha',
    vibe: 'Curious',
    initial: 'A',
    gradientFrom: Color(0xFFFF7043),
    gradientTo: Color(0xFFF4C430),
    accentColor: Color(0xFFFF7043),
    sportIcon: Icons.self_improvement,
    quote:
        "I moved to a new city and didn't know a single soul here.\n\nFinding people who shared my vibe shouldn't be this hard.",
    highlightWord: 'Finding people who shared my vibe',
    highlightColor: Color(0xFFFF7043),
  ),
];

class _Testimonial {
  final String name;
  final String vibe;
  final String initial;
  final Color gradientFrom;
  final Color gradientTo;
  final Color accentColor;
  final IconData sportIcon;
  final String quote;
  final String highlightWord;
  final Color highlightColor;

  const _Testimonial({
    required this.name,
    required this.vibe,
    required this.initial,
    required this.gradientFrom,
    required this.gradientTo,
    required this.accentColor,
    required this.sportIcon,
    required this.quote,
    required this.highlightWord,
    required this.highlightColor,
  });
}

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
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _idx = (_idx + 1) % _kTestimonials.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openLanguagePicker() {
    showAdaptiveSheet<void>(
      context: context,
      builder: (ctx) => _LandingLanguagePickerSheet(ref: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final langLabel = locale.languageCode == 'ar' ? 'العربية' : 'English';
    final t = _kTestimonials[_idx];

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: GradientBlob(
                color: t.accentColor,
                size: 360,
                opacity: 0.33,
              ),
            ),
            Positioned(
              bottom: 80,
              left: -100,
              child: GradientBlob(
                color: t.accentColor,
                size: 320,
                opacity: 0.18,
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: SvgPicture.asset(
                    'assets/images/dabbler_text_logo.svg',
                    height: 22,
                    colorFilter: ColorFilter.mode(
                      colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: _UserIdentityRow(key: ValueKey(_idx), t: t),
                        ),
                        const SizedBox(height: 28),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: _QuoteText(key: ValueKey('q$_idx'), t: t),
                        ),
                        const Spacer(),
                        Row(
                          children: List.generate(_kTestimonials.length, (i) {
                            final active = i == _idx;
                            return GestureDetector(
                              onTap: () => setState(() => _idx = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                margin: const EdgeInsets.only(right: 6),
                                width: active ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: active ? t.accentColor : colorScheme.outline,
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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dabbler connects players, captains, and venues — so you can stop searching and start playing.',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OnboardingCTAButton(
                        label: AppLocalizations.of(context).landing_continue,
                        onPressed: () => context.go(RoutePaths.authWelcome),
                        // icon: const Icon(Icons.arrow_forward,
                        //     size: 20, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: GlassPill(
                          icon: Icons.language_rounded,
                          label: langLabel,
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
          ],
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
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.gradientFrom, t.gradientTo],
            ),
            boxShadow: [
              BoxShadow(
                color: t.accentColor.withValues(alpha: 0.31),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(
              t.initial,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: t.accentColor.withValues(alpha: 0.10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.sportIcon, size: 13, color: t.accentColor),
                  const SizedBox(width: 5),
                  Text(
                    t.vibe.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: t.accentColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ],
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
    final colorScheme = Theme.of(context).colorScheme;
    final parts = t.quote.split(t.highlightWord);
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          height: 1.3,
          letterSpacing: -0.5,
        ),
        children: [
          if (parts.isNotEmpty) TextSpan(text: parts[0]),
          TextSpan(
            text: t.highlightWord,
            style: TextStyle(color: t.highlightColor),
          ),
          if (parts.length > 1) TextSpan(text: parts[1]),
        ],
      ),
    );
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final current = ref.watch(localeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppLocalizations.of(context).landing_choose_language,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
        ..._languages.map((lang) {
          final isSelected = current.languageCode == lang['code'];
          return ListTile(
            title: Text(
              lang['name']!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w800 : null,
                color: colorScheme.onSurface,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check, color: colorScheme.primary)
                : null,
            onTap: () {
              ref
                  .read(localeProvider.notifier)
                  .setLocale(Locale(lang['code']!));
              Navigator.of(context).pop();
            },
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }
}
