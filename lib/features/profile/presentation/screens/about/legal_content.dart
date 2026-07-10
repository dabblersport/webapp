import 'package:flutter/material.dart';

/// A single titled section of a legal document.
class LegalSection {
  const LegalSection(this.title, this.content);
  final String title;
  final String content;
}

const String kLegalLastUpdated = 'January 25, 2025';

const String kTermsIntro =
    'Please read these terms carefully before using our service.';

const String kPrivacyIntro =
    'Your privacy is important to us. This policy explains how we collect, '
    'use, and protect your information.';

const List<LegalSection> kTermsOfServiceSections = [
  LegalSection(
    '1. Acceptance of Terms',
    'By accessing and using Dabbler ("the Service"), you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
  ),
  LegalSection(
    '2. Description of Service',
    'Dabbler is a social sports platform that connects users to play sports and games together. The Service provides features for user profiles, game matching, social interaction, and activity tracking.',
  ),
  LegalSection(
    '3. User Accounts',
    'To use certain features of the Service, you must register for an account. You agree to:\n'
        '• Provide accurate, current, and complete information\n'
        '• Maintain the security of your password\n'
        '• Accept responsibility for all activities under your account\n'
        '• Notify us immediately of any unauthorized use',
  ),
  LegalSection(
    '4. User Conduct',
    'You agree not to use the Service to:\n'
        '• Upload, post, or transmit harmful, threatening, or inappropriate content\n'
        '• Harass, abuse, or harm other users\n'
        '• Violate any applicable laws or regulations\n'
        '• Impersonate any person or entity\n'
        '• Interfere with or disrupt the Service',
  ),
  LegalSection(
    '5. User-Generated Content & Zero-Tolerance Policy',
    'Dabbler lets you post content and interact with other people. There is ZERO TOLERANCE for objectionable content or abusive users. By using the Service you agree that you will not create, upload, post, or share content that is unlawful, harmful, threatening, abusive, harassing, defamatory, obscene, hateful, sexually explicit, or otherwise objectionable, and that you will not harass, bully, impersonate, threaten, or abuse other users.\n\n'
        'To keep the community safe, the Service gives every user built-in tools to:\n'
        '• Report or flag objectionable content — a report control is available on each piece of user content and sends the report to our moderation team.\n'
        '• Block abusive users — blocking a user immediately hides their content from you and stops further interaction between you.\n\n'
        'We review reports and act on objectionable content and abusive behavior — including removing the content and ejecting the users who provided it — within 24 hours where reasonably possible. You must agree to these terms before you can register or use the Service. We may remove content and suspend or terminate accounts that violate this policy, with or without notice.',
  ),
  LegalSection(
    '6. Content and Privacy',
    'You retain ownership of content you post on the Service. By posting content, you grant us a non-exclusive, royalty-free license to use, modify, and display such content. Our Privacy Policy explains how we collect and use your information.',
  ),
  LegalSection(
    '7. Game Participation',
    'Participation in sports and games organized through the Service is at your own risk. We do not assume responsibility for injuries or damages that may occur during activities. Users are responsible for their own safety and should assess their fitness level before participating.',
  ),
  LegalSection(
    '8. Payment and Fees',
    'Some features of the Service may require payment. All fees are non-refundable unless otherwise stated. We reserve the right to change our pricing at any time with notice to users.',
  ),
  LegalSection(
    '9. Intellectual Property',
    'The Service and its original content, features, and functionality are owned by Dabbler and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.',
  ),
  LegalSection(
    '10. Termination',
    'We may terminate or suspend your account and access to the Service at our sole discretion, without prior notice, for conduct that we believe violates these Terms or is harmful to other users.',
  ),
  LegalSection(
    '11. Disclaimers',
    'The Service is provided "as is" without warranties of any kind. We disclaim all warranties, express or implied, including merchantability, fitness for a particular purpose, and non-infringement.',
  ),
  LegalSection(
    '12. Limitation of Liability',
    'In no event shall Dabbler be liable for any indirect, incidental, special, consequential, or punitive damages, including lost profits, arising from your use of the Service.',
  ),
  LegalSection(
    '13. Governing Law',
    'These Terms shall be governed by and construed in accordance with the laws of [Jurisdiction], without regard to its conflict of law provisions.',
  ),
  LegalSection(
    '14. Changes to Terms',
    'We reserve the right to modify these Terms at any time. We will notify users of any changes by posting the new Terms on this page. Your continued use of the Service after changes constitutes acceptance of the new Terms.',
  ),
  LegalSection(
    'Questions about these Terms?',
    'If you have any questions about these Terms of Service, please contact us at:\n'
        'Email: legal@dabbler.com\n'
        'Address: [Company Address]',
  ),
];

const List<LegalSection> kPrivacyPolicySections = [
  LegalSection(
    '1. Information We Collect',
    'We collect information you provide directly to us, such as:\n'
        '• Personal information (name, email, phone number)\n'
        '• Profile information (bio, sports preferences, skill level)\n'
        '• Activity data (games played, locations, performance)\n'
        '• Communications with us and other users\n'
        '• Device information and usage data',
  ),
  LegalSection(
    '2. How We Use Your Information',
    'We use your information to:\n'
        '• Provide and improve our services\n'
        '• Match you with other players and activities\n'
        '• Communicate with you about our services\n'
        '• Personalize your experience\n'
        '• Ensure safety and security\n'
        '• Comply with legal obligations',
  ),
  LegalSection(
    '3. Information Sharing',
    'We may share your information:\n'
        '• With other users as part of the service (profile information)\n'
        '• With service providers who assist us\n'
        '• When required by law or to protect rights and safety\n'
        '• In connection with business transfers\n'
        '• With your consent for other purposes',
  ),
  LegalSection(
    '4. Location Information',
    'We collect location data to:\n'
        '• Show nearby games and activities\n'
        '• Provide location-based recommendations\n'
        '• Improve our mapping and navigation features\n'
        'You can disable location sharing in your device settings at any time.',
  ),
  LegalSection(
    '5. Data Security',
    'We implement appropriate security measures to protect your information, including:\n'
        '• Encryption of sensitive data\n'
        '• Secure data transmission\n'
        '• Regular security assessments\n'
        '• Access controls and authentication\n'
        'However, no method of transmission over the internet is 100% secure.',
  ),
  LegalSection(
    '6. Data Retention',
    'We retain your information for as long as necessary to:\n'
        '• Provide our services\n'
        '• Comply with legal obligations\n'
        '• Resolve disputes\n'
        '• Enforce our agreements\n'
        'You can request deletion of your account and data at any time.',
  ),
  LegalSection(
    '7. Your Privacy Rights',
    'You have the right to:\n'
        '• Access your personal information\n'
        '• Correct inaccurate information\n'
        '• Delete your account and data\n'
        '• Object to processing of your data\n'
        '• Export your data\n'
        '• Withdraw consent where applicable',
  ),
  LegalSection(
    '8. Cookies and Tracking',
    'We use cookies and similar technologies to:\n'
        '• Remember your preferences\n'
        '• Analyze usage patterns\n'
        '• Personalize content\n'
        '• Improve our services\n'
        'You can manage cookie preferences in your browser settings.',
  ),
  LegalSection(
    '9. Third-Party Services',
    'Our app may integrate with third-party services such as:\n'
        '• Social media platforms\n'
        '• Payment processors\n'
        '• Analytics providers\n'
        '• Map services\n'
        'These services have their own privacy policies that govern their use of your information.',
  ),
  LegalSection(
    "10. Children's Privacy",
    'Our service is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected such information, we will take steps to delete it.',
  ),
  LegalSection(
    '11. International Transfers',
    'Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place to protect your information in accordance with applicable privacy laws.',
  ),
  LegalSection(
    '12. Changes to This Policy',
    'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new policy on this page and updating the "Last updated" date. Your continued use constitutes acceptance of the changes.',
  ),
  LegalSection(
    'Privacy Questions?',
    'If you have any questions about this Privacy Policy or our privacy practices, please contact us:\n'
        'Email: privacy@dabbler.com\n'
        'Address: [Company Address]\n'
        'Data Protection Officer: [DPO Contact]',
  ),
];

/// Native, scrollable legal-document body. Shared by the in-app drawer
/// ([showLegalDocSheet]) and the full `/about/*` screens so the legal text has
/// a single source of truth.
class LegalDocContent extends StatelessWidget {
  const LegalDocContent({
    super.key,
    required this.intro,
    required this.sections,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  });

  final String intro;
  final List<LegalSection> sections;
  final ScrollController? controller;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      controller: controller,
      padding: padding,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            intro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.update,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Last updated: $kLegalLastUpdated',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final section in sections) ...[
            Text(
              section.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              section.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
