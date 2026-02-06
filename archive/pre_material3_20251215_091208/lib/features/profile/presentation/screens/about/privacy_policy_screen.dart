import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen displaying the Privacy Policy
class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  ConsumerState<PrivacyPolicyScreen> createState() =>
      _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupScrollListener();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      setState(() {
        _isScrolled = _scrollController.offset > 100;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        elevation: _isScrolled ? 2 : 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePolicy,
            tooltip: 'Share Policy',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(),
                const SizedBox(height: 30),
                _buildLastUpdatedSection(),
                const SizedBox(height: 30),
                _buildPrivacyContent(),
                const SizedBox(height: 30),
                _buildContactSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.privacy_tip, size: 48, color: Colors.blue.shade700),
            const SizedBox(height: 16),
            Text(
              'Privacy Policy',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your privacy is important to us. This policy explains how we collect, use, and protect your information.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdatedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.update, color: Colors.grey[600], size: 20),
            const SizedBox(width: 8),
            Text(
              'Last updated: January 25, 2025',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          title: '1. Information We Collect',
          content:
              'We collect information you provide directly to us, such as:\n'
              '• Personal information (name, email, phone number)\n'
              '• Profile information (bio, sports preferences, skill level)\n'
              '• Activity data (games played, locations, performance)\n'
              '• Communications with us and other users\n'
              '• Device information and usage data',
        ),

        _buildSection(
          title: '2. How We Use Your Information',
          content:
              'We use your information to:\n'
              '• Provide and improve our services\n'
              '• Match you with other players and activities\n'
              '• Communicate with you about our services\n'
              '• Personalize your experience\n'
              '• Ensure safety and security\n'
              '• Comply with legal obligations',
        ),

        _buildSection(
          title: '3. Information Sharing',
          content:
              'We may share your information:\n'
              '• With other users as part of the service (profile information)\n'
              '• With service providers who assist us\n'
              '• When required by law or to protect rights and safety\n'
              '• In connection with business transfers\n'
              '• With your consent for other purposes',
        ),

        _buildSection(
          title: '4. Location Information',
          content:
              'We collect location data to:\n'
              '• Show nearby games and activities\n'
              '• Provide location-based recommendations\n'
              '• Improve our mapping and navigation features\n'
              'You can disable location sharing in your device settings at any time.',
        ),

        _buildSection(
          title: '5. Data Security',
          content:
              'We implement appropriate security measures to protect your information, including:\n'
              '• Encryption of sensitive data\n'
              '• Secure data transmission\n'
              '• Regular security assessments\n'
              '• Access controls and authentication\n'
              'However, no method of transmission over the internet is 100% secure.',
        ),

        _buildSection(
          title: '6. Data Retention',
          content:
              'We retain your information for as long as necessary to:\n'
              '• Provide our services\n'
              '• Comply with legal obligations\n'
              '• Resolve disputes\n'
              '• Enforce our agreements\n'
              'You can request deletion of your account and data at any time.',
        ),

        _buildSection(
          title: '7. Your Privacy Rights',
          content:
              'You have the right to:\n'
              '• Access your personal information\n'
              '• Correct inaccurate information\n'
              '• Delete your account and data\n'
              '• Object to processing of your data\n'
              '• Export your data\n'
              '• Withdraw consent where applicable',
        ),

        _buildSection(
          title: '8. Cookies and Tracking',
          content:
              'We use cookies and similar technologies to:\n'
              '• Remember your preferences\n'
              '• Analyze usage patterns\n'
              '• Personalize content\n'
              '• Improve our services\n'
              'You can manage cookie preferences in your browser settings.',
        ),

        _buildSection(
          title: '9. Third-Party Services',
          content:
              'Our app may integrate with third-party services such as:\n'
              '• Social media platforms\n'
              '• Payment processors\n'
              '• Analytics providers\n'
              '• Map services\n'
              'These services have their own privacy policies that govern their use of your information.',
        ),

        _buildSection(
          title: '10. Children\'s Privacy',
          content:
              'Our service is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected such information, we will take steps to delete it.',
        ),

        _buildSection(
          title: '11. International Transfers',
          content:
              'Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place to protect your information in accordance with applicable privacy laws.',
        ),

        _buildSection(
          title: '12. Changes to This Policy',
          content:
              'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new policy on this page and updating the "Last updated" date. Your continued use constitutes acceptance of the changes.',
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contact_support, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Privacy Questions?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'If you have any questions about this Privacy Policy or our privacy practices, please contact us:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Email: privacy@dabbler.com\n'
              'Address: [Company Address]\n'
              'Data Protection Officer: [DPO Contact]',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _contactSupport,
                    child: const Text('Contact Us'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _managePrivacySettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                    ),
                    child: const Text(
                      'Privacy Settings',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sharePolicy() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  void _contactSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact support functionality coming soon'),
      ),
    );
  }

  void _managePrivacySettings() {
    context.push('/settings/privacy');
  }
}
