import 'package:flutter/material.dart';

import 'package:dabbler/features/profile/presentation/screens/about/legal_content.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';

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

/// Presents a legal document with native, scrollable content inside the app's
/// adaptive drawer (bottom sheet on phones, centered dialog on wide viewports).
Future<void> showLegalDocSheet({
  required BuildContext context,
  required String title,
  required String intro,
  required List<LegalSection> sections,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    builder: (_) => _LegalDocSheet(
      title: title,
      intro: intro,
      sections: sections,
    ),
  );
}

class _LegalDocSheet extends StatelessWidget {
  const _LegalDocSheet({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fill the adaptive dialog on wide screens; take ~85% of the screen as
        // a bottom sheet on phones. Clamp to the incoming max so the scrollable
        // body always has a bounded height.
        final screenHeight = MediaQuery.sizeOf(context).height;
        final desired = screenHeight * 0.85;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight.clamp(0.0, desired)
            : desired;

        return SizedBox(
          height: height,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: Icon(Icons.close, color: colorScheme.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),
              Expanded(
                child: LegalDocContent(intro: intro, sections: sections),
              ),
            ],
          ),
        );
      },
    );
  }
}
