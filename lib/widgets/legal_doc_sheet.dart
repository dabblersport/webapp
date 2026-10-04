import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/profile/presentation/screens/about/legal_content.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Opens the Terms of Service in an in-app drawer.
Future<void> showTermsSheet(BuildContext context) => showLegalDocSheet(
  context: context,
  title: AppLocalizations.of(context).settings_item_terms_title,
  intro: AppLocalizations.of(context).about_terms_intro,
  sections: kTermsOfServiceSections,
);

/// Opens the Privacy Policy in an in-app drawer.
Future<void> showPrivacySheet(BuildContext context) => showLegalDocSheet(
  context: context,
  title: AppLocalizations.of(context).settings_item_privacy_policy_title,
  intro: AppLocalizations.of(context).about_privacy_intro,
  sections: kPrivacyPolicySections,
);

/// Presents a legal document with native, scrollable content inside the
/// design-system sheet. The sheet draws the title and its own close control;
/// the body is a bounded box so the long document scrolls inside it.
Future<void> showLegalDocSheet({
  required BuildContext context,
  required String title,
  required String intro,
  required List<LegalSection> sections,
}) {
  return showDabblerSheet<void>(
    context: context,
    title: title,
    detent: DabblerSheetDetent.content,
    builder: (_) => LegalDocSheetBody(intro: intro, sections: sections),
  );
}

/// The sheet body: [LegalDocContent] held at 70% of the screen height.
class LegalDocSheetBody extends StatelessWidget {
  const LegalDocSheetBody({
    super.key,
    required this.intro,
    required this.sections,
  });

  final String intro;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height:
          MediaQuery.sizeOf(context).height *
          DabblerSheet.defaultContentMaxFraction,
      child: LegalDocContent(
        intro: intro,
        sections: sections,
        padding: const EdgeInsetsDirectional.only(
          bottom: DabblerSpacing.space8,
        ),
      ),
    );
  }
}
