import 'package:dabbler/features/profile/presentation/screens/about/legal_content.dart'
    show
        LegalSection,
        kLegalLastUpdated,
        kPrivacyIntro,
        kPrivacyPolicySections,
        kTermsIntro,
        kTermsOfServiceSections;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Shared, design-system-only pieces for the entry screens (landing, welcome,
/// auth, email, password). Nothing here is Material.

/// A design-system type step resolved for the ambient text direction, with an
/// optional colour override.
TextStyle authText(
  BuildContext context,
  DabblerTypeStyle step, {
  Color? color,
  FontWeight? weight,
}) {
  final TextStyle base = step.resolveForDirection(Directionality.of(context));
  return base.copyWith(color: color, fontWeight: weight);
}

final RegExp _emojiRun = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]+',
  unicode: true,
);

/// Removes emoji from a localized string (the design system carries none).
String authStripEmoji(String text) =>
    text.replaceAll(_emojiRun, '').replaceAll(RegExp(r'\s+$'), '');

/// Opens the Terms of Service in a design-system sheet.
Future<void> showAuthTermsSheet(BuildContext context) => _showLegal(
  context,
  title: 'Terms of Service',
  intro: kTermsIntro,
  sections: kTermsOfServiceSections,
);

/// Opens the Privacy Policy in a design-system sheet.
Future<void> showAuthPrivacySheet(BuildContext context) => _showLegal(
  context,
  title: 'Privacy Policy',
  intro: kPrivacyIntro,
  sections: kPrivacyPolicySections,
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
    builder: (BuildContext ctx) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space8,
          0,
          DabblerSpacing.space8,
          DabblerSpacing.space8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DabblerText(
              intro,
              style: DabblerType.subheadline,
              tone: DabblerTextTone.secondary,
            ),
            const SizedBox(height: DabblerSpacing.space2),
            DabblerText(
              'Last updated: $kLegalLastUpdated',
              style: DabblerType.caption1,
              tone: DabblerTextTone.secondary,
            ),
            const SizedBox(height: DabblerSpacing.space6),
            for (final LegalSection s in sections) ...<Widget>[
              DabblerText(
                s.title,
                style: DabblerType.headline,
                tone: DabblerTextTone.brand,
              ),
              const SizedBox(height: DabblerSpacing.space2),
              DabblerText(s.content, style: DabblerType.subheadline),
              const SizedBox(height: DabblerSpacing.space6),
            ],
          ],
        ),
      );
    },
  );
}

/// "By continuing you agree to our Terms and Privacy Policy." with the two
/// links opening the legal sheets.
class AuthLegalNotice extends StatelessWidget {
  const AuthLegalNotice({super.key, this.center = true});

  final bool center;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DabblerText.rich(
      <DabblerTextSpan>[
        DabblerTextSpan(l10n.email_input_terms_prefix),
        DabblerTextSpan(
          l10n.email_input_terms_link,
          onTap: () => showAuthTermsSheet(context),
        ),
        DabblerTextSpan(l10n.email_input_terms_and),
        DabblerTextSpan(
          l10n.email_input_privacy_link,
          onTap: () => showAuthPrivacySheet(context),
        ),
        const DabblerTextSpan('.'),
      ],
      style: DabblerType.caption1,
      tone: DabblerTextTone.secondary,
      textAlign: center ? TextAlign.center : TextAlign.start,
    );
  }
}

/// An inline error (or success) message.
class AuthInlineMessage extends StatelessWidget {
  const AuthInlineMessage({
    super.key,
    required this.message,
    this.success = false,
  });

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return DabblerBanner(
      tone: success ? DabblerBannerTone.success : DabblerBannerTone.error,
      message: message,
    );
  }
}

/// A tappable row for a picker sheet (language / country): title plus a tick
/// when selected.
class AuthPickerRow extends StatelessWidget {
  const AuthPickerRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DabblerInputRow(
      title: title,
      onTap: onTap,
      trailing: selected
          ? DabblerIcon(
              'tick-circle',
              weight: DabblerIconWeight.bold,
              color: DabblerColors.of(context).brandPrimary,
            )
          : null,
    );
  }
}

/// Wraps [child] with a stable semantics identifier for end-to-end tests.
Widget authIdentify(String? identifier, Widget child) => identifier == null
    ? child
    : MergeSemantics(
        child: Semantics(identifier: identifier, child: child),
      );
