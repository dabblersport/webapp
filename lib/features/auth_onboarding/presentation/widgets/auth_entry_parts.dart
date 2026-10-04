import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/profile/presentation/screens/about/legal_content.dart'
    show
        LegalSection,
        kLegalLastUpdated,
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

/// Removes emoji from a localized string (the design system carries none).
String authStripEmoji(String text) =>
    text.replaceAll(_emojiRun, '').replaceAll(RegExp(r'\s+$'), '');

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
    detents: const <double>[0.85],
    footerBuilder: _gotIt,
    builder: (BuildContext ctx) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DabblerText(
            intro,
            style: DabblerType.subheadline,
            tone: DabblerTextTone.secondary,
          ),
          const DabblerGap.v(DabblerSpacing.space2),
          DabblerText(
            'Last updated: $kLegalLastUpdated',
            style: DabblerType.caption1,
            tone: DabblerTextTone.secondary,
          ),
          for (final LegalSection s in sections) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space6),
            DabblerText(s.title, style: DabblerType.headline),
            const DabblerGap.v(DabblerSpacing.space2),
            DabblerText(
              s.content,
              style: DabblerType.subheadline,
              tone: DabblerTextTone.secondary,
            ),
          ],
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
      style: DabblerType.caption1,
      tone: DabblerTextTone.secondary,
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
      style: DabblerType.subheadline,
      tone: DabblerTextTone.secondary,
      textAlign: TextAlign.center,
    );
  }
}

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
      footerBuilder: _done,
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
                DabblerInputRow(
                  flat: true,
                  title: name,
                  selected: current == code,
                  onTap: () =>
                      ref.read(localeProvider.notifier).setLocale(Locale(code)),
                ),
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
      detents: const <double>[0.6],
      footerBuilder: _done,
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
                  DabblerInputRow(
                    flat: true,
                    title: _localized(c['name_en'] as String, languageCode),
                    selected: c['name_en'] == selected,
                    onTap: () => ref
                        .read(selectedCountryProvider.notifier)
                        .setCountry(c['name_en'] as String),
                  ),
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
        DabblerChip(label: countryName, onTap: _openRegion),
        const DabblerGap.h(DabblerSpacing.space3),
        DabblerChip(
          label: languageCode == 'ar' ? 'العربية' : 'English',
          onTap: _openLanguage,
        ),
      ],
    );
  }
}
