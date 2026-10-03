import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/profile/presentation/screens/about/legal_content.dart';

/// Opens the Terms of Service in an in-app drawer.
Future<void> showTermsSheet(BuildContext context) => showLegalDocSheet(
  context: context,
  title: 'Terms of Service',
  intro: kTermsIntro,
  sections: kTermsOfServiceSections,
);

/// Opens the Privacy Policy in an in-app drawer.
Future<void> showPrivacySheet(BuildContext context) => showLegalDocSheet(
  context: context,
  title: 'Privacy Policy',
  intro: kPrivacyIntro,
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
      height: MediaQuery.sizeOf(context).height * 0.7,
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
