import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/profile/presentation/screens/about/legal_content.dart'
    show
        LegalSection,
        kPrivacyIntro,
        kPrivacyPolicySections,
        kTermsIntro,
        kTermsOfServiceSections;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/providers.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared, design-system-only pieces for the entry screens (landing, auth
/// entry, email sign-up, log in). Nothing here draws anything of its own: each
/// piece is a composition of design-system components.

final RegExp _emojiRun = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]+',
  unicode: true,
);

/// Whether the on-screen keyboard is open. The login and sign-up email screens
/// follow it: with the keyboard up they keep only the title, the fields and the
/// primary action (and the code link) above it, so the active field is never
/// hidden; the back header and the secondary group (Google, Apple, Create an
/// account) wait below the keyboard and return when it closes.
bool authKeyboardOpen(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom > 0;

/// The room left above the keyboard (below the status bar) on a small phone:
/// under this the subtitle gives way as well, so the fields and the primary
/// action are never squeezed or overlapped. A real iPhone SE with its keyboard
/// leaves about 356.
const double kAuthTightHeight = 420;

/// Whether the keyboard is open AND the room above it is [kAuthTightHeight] or
/// less (a small phone, or a large text size).
bool authKeyboardTight(BuildContext context) {
  final media = MediaQuery.of(context);
  return media.viewInsets.bottom > 0 &&
      media.size.height - media.viewInsets.bottom - media.padding.top <=
          kAuthTightHeight;
}

/// Removes emoji from a localized string (the design system carries none).
String authStripEmoji(String text) =>
    text.replaceAll(_emojiRun, '').replaceAll(RegExp(r'\s+$'), '');

/// A link's text style at the frame's [role], medium weight, resolved for the
/// ambient direction (`DabblerTextLink` takes a resolved style).
TextStyle authLinkStyle(BuildContext context, DabblerTypeStyle role) => role
    .resolveForDirection(Directionality.of(context))
    .copyWith(fontWeight: DabblerType.medium);

/// Wraps [child] with a stable semantics identifier for end-to-end tests.
Widget authIdentify(String? identifier, Widget child) => identifier == null
    ? child
    : MergeSemantics(
        child: Semantics(identifier: identifier, child: child),
      );

/// Opens the Terms of Service in a design-system sheet.
Future<void> showAuthTermsSheet(BuildContext context) => _showLegal(
  context,
  title: AppLocalizations.of(context).auth_legal_terms,
  intro: kTermsIntro,
  sections: kTermsOfServiceSections,
);

/// Opens the Privacy Policy in a design-system sheet.
Future<void> showAuthPrivacySheet(BuildContext context) => _showLegal(
  context,
  title: AppLocalizations.of(context).auth_legal_privacy,
  intro: kPrivacyIntro,
  sections: kPrivacyPolicySections,
);

Widget _gotIt(BuildContext sheetContext) => DabblerButton(
  label: AppLocalizations.of(sheetContext).auth_sheet_got_it,
  size: DabblerButtonSize.full,
  fullWidth: true,
  onPressed: () => Navigator.of(sheetContext).pop(),
);

Widget _done(BuildContext sheetContext) => DabblerButton(
  label: AppLocalizations.of(sheetContext).auth_sheet_done,
  size: DabblerButtonSize.full,
  fullWidth: true,
  onPressed: () => Navigator.of(sheetContext).pop(),
);

Future<void> _showLegal(
  BuildContext context, {
  required String title,
  required String intro,
  required List<LegalSection> sections,
}) {
  return showDabblerSheet<void>(
    context: context,
    title: title,
    detent: DabblerSheetDetent.content,
    showCloseButton: false,
    builder: (BuildContext ctx) {
      // The frame's legal sheet is plain paragraphs, 15/22 soft ink, 15 apart
      // (`Auth and Onboarding.dc.html:551-555`).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DabblerText(
            intro,
            style: DabblerType.copyRelaxed,
            tone: DabblerTextTone.secondary,
          ),
          for (final LegalSection s in sections) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space5),
            DabblerText(
              s.content,
              style: DabblerType.copyRelaxed,
              tone: DabblerTextTone.secondary,
            ),
          ],
          // The frame's action is the sheet's last child, 12 under the text.
          const DabblerGap.v(DabblerSpacing.space4),
          _gotIt(ctx),
        ],
      );
    },
  );
}

/// "By continuing you agree to our Terms and Privacy Policy." with the two
/// links opening the legal sheets.
class AuthLegalNotice extends StatelessWidget {
  const AuthLegalNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DabblerText.rich(
      <DabblerTextSpan>[
        DabblerTextSpan(l10n.auth_legal_prefix),
        DabblerTextSpan(
          l10n.auth_legal_terms,
          onTap: () => showAuthTermsSheet(context),
        ),
        DabblerTextSpan(l10n.auth_legal_and),
        DabblerTextSpan(
          l10n.auth_legal_privacy,
          onTap: () => showAuthPrivacySheet(context),
        ),
        const DabblerTextSpan('.'),
      ],
      style: DabblerType.captionRelaxed,
      tone: DabblerTextTone.tertiary,
      textAlign: TextAlign.center,
    );
  }
}

/// A centred sentence with one link at its end — "Already have an account?
/// Log in", "New here? Create an account".
class AuthAccountLine extends StatelessWidget {
  const AuthAccountLine({
    super.key,
    required this.prefix,
    required this.action,
    this.onAction,
  });

  final String prefix;
  final String action;

  /// Null leaves the link inert (while a request is in flight).
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DabblerText.rich(
      <DabblerTextSpan>[
        DabblerTextSpan('$prefix '),
        DabblerTextSpan(
          action,
          weight: DabblerTextWeight.medium,
          onTap: onAction,
        ),
      ],
      style: DabblerType.copy,
      tone: DabblerTextTone.secondary,
      textAlign: TextAlign.center,
    );
  }
}

/// Seeds the region sheet's countries (render tests have no network).
@visibleForTesting
List<Map<String, dynamic>>? debugAuthCountries;

/// The region and language chips that close the welcome and entry frames, and
/// the two sheets they open.
class AuthLocaleChips extends ConsumerStatefulWidget {
  const AuthLocaleChips({super.key});

  @override
  ConsumerState<AuthLocaleChips> createState() => _AuthLocaleChipsState();
}

class _AuthLocaleChipsState extends ConsumerState<AuthLocaleChips> {
  List<Map<String, dynamic>> _countries = <Map<String, dynamic>>[];
  bool _countriesLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCountries();
  }

  Future<void> _fetchCountries() async {
    final List<Map<String, dynamic>>? seeded = debugAuthCountries;
    if (seeded != null) {
      _countries = seeded;
      _countriesLoading = false;
      return;
    }
    try {
      final dynamic response = await Supabase.instance.client
          .from(SupabaseConfig.refCountriesTable)
          .select('name_en, name_ar')
          .eq('coverage', true)
          .order('name_en');
      if (mounted) {
        setState(() {
          _countries = (response as List).cast<Map<String, dynamic>>();
          _countriesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _countriesLoading = false);
    }
  }

  /// Countries are persisted/selected by their English name (canonical id),
  /// but displayed in the active locale when a translation is available.
  String _localized(String englishName, String languageCode) {
    if (languageCode != 'ar') return englishName;
    for (final Map<String, dynamic> country in _countries) {
      if (country['name_en'] == englishName) {
        final String? ar = country['name_ar'] as String?;
        if (ar != null && ar.isNotEmpty) return ar;
      }
    }
    return englishName;
  }

  Future<void> _openLanguage() {
    return showDabblerSheet<void>(
      context: context,
      title: AppLocalizations.of(context).auth_sheet_language,
      detent: DabblerSheetDetent.content,
      showCloseButton: false,
      builder: (BuildContext ctx) => Consumer(
        builder: (BuildContext ctx, WidgetRef ref, Widget? _) {
          final String current = ref.watch(localeProvider).languageCode;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final (String code, String name) in <(String, String)>[
                ('en', 'English'),
                ('ar', 'العربية'),
              ])
                DabblerInputRow.option(
                  title: name,
                  selected: current == code,
                  // The language's own name reads in its own script
                  // (`Auth and Onboarding.dc.html:2124`).
                  textDirection: code == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  onTap: () =>
                      ref.read(localeProvider.notifier).setLocale(Locale(code)),
                ),
              // The frame's action is the sheet's last child (`:585`).
              const DabblerGap.v(DabblerSpacing.space4),
              _done(ctx),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openRegion() {
    return showDabblerSheet<void>(
      context: context,
      title: AppLocalizations.of(context).auth_sheet_region,
      detent: DabblerSheetDetent.content,
      showCloseButton: false,
      builder: (BuildContext ctx) {
        if (_countriesLoading) {
          return const Center(child: DabblerSpinner());
        }
        return Consumer(
          builder: (BuildContext ctx, WidgetRef ref, Widget? _) {
            final String? selected = ref
                .watch(selectedCountryProvider)
                .valueOrNull;
            final String languageCode = ref.watch(localeProvider).languageCode;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final Map<String, dynamic> c in _countries)
                  DabblerInputRow.option(
                    title: _localized(c['name_en'] as String, languageCode),
                    selected: c['name_en'] == selected,
                    onTap: () => ref
                        .read(selectedCountryProvider.notifier)
                        .setCountry(c['name_en'] as String),
                  ),
                const DabblerGap.v(DabblerSpacing.space4),
                _done(ctx),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String languageCode = ref.watch(localeProvider).languageCode;
    final String countryName = ref
        .watch(selectedCountryProvider)
        .maybeWhen(
          data: (String c) => _localized(c, languageCode),
          orElse: () => 'Global',
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        DabblerChip(
          label: countryName,
          compactHitArea: true,
          onTap: _openRegion,
        ),
        const DabblerGap.h(DabblerSpacing.space3),
        DabblerChip(
          compactHitArea: true,
          label: languageCode == 'ar' ? 'العربية' : 'English',
          onTap: _openLanguage,
        ),
      ],
    );
  }
}
