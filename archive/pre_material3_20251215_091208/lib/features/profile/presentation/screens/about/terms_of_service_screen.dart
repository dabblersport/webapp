import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen displaying the Terms of Service
class TermsOfServiceScreen extends ConsumerStatefulWidget {
  const TermsOfServiceScreen({super.key});

  @override
  ConsumerState<TermsOfServiceScreen> createState() =>
      _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends ConsumerState<TermsOfServiceScreen>
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
        title: const Text('Terms of Service'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        elevation: _isScrolled ? 2 : 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareTerms,
            tooltip: 'Share Terms',
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
                _buildTermsContent(),
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
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.description,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Terms of Service',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please read these terms carefully before using our service.',
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

  Widget _buildTermsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          title: '1. Acceptance of Terms',
          content:
              'By accessing and using Dabbler ("the Service"), you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
        ),

        _buildSection(
          title: '2. Description of Service',
          content:
              'Dabbler is a social sports platform that connects users to play sports and games together. The Service provides features for user profiles, game matching, social interaction, and activity tracking.',
        ),

        _buildSection(
          title: '3. User Accounts',
          content:
              'To use certain features of the Service, you must register for an account. You agree to:\n'
              '• Provide accurate, current, and complete information\n'
              '• Maintain the security of your password\n'
              '• Accept responsibility for all activities under your account\n'
              '• Notify us immediately of any unauthorized use',
        ),

        _buildSection(
          title: '4. User Conduct',
          content:
              'You agree not to use the Service to:\n'
              '• Upload, post, or transmit harmful, threatening, or inappropriate content\n'
              '• Harass, abuse, or harm other users\n'
              '• Violate any applicable laws or regulations\n'
              '• Impersonate any person or entity\n'
              '• Interfere with or disrupt the Service',
        ),

        _buildSection(
          title: '5. Content and Privacy',
          content:
              'You retain ownership of content you post on the Service. By posting content, you grant us a non-exclusive, royalty-free license to use, modify, and display such content. Our Privacy Policy explains how we collect and use your information.',
        ),

        _buildSection(
          title: '6. Game Participation',
          content:
              'Participation in sports and games organized through the Service is at your own risk. We do not assume responsibility for injuries or damages that may occur during activities. Users are responsible for their own safety and should assess their fitness level before participating.',
        ),

        _buildSection(
          title: '7. Payment and Fees',
          content:
              'Some features of the Service may require payment. All fees are non-refundable unless otherwise stated. We reserve the right to change our pricing at any time with notice to users.',
        ),

        _buildSection(
          title: '8. Intellectual Property',
          content:
              'The Service and its original content, features, and functionality are owned by Dabbler and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.',
        ),

        _buildSection(
          title: '9. Termination',
          content:
              'We may terminate or suspend your account and access to the Service at our sole discretion, without prior notice, for conduct that we believe violates these Terms or is harmful to other users.',
        ),

        _buildSection(
          title: '10. Disclaimers',
          content:
              'The Service is provided "as is" without warranties of any kind. We disclaim all warranties, express or implied, including merchantability, fitness for a particular purpose, and non-infringement.',
        ),

        _buildSection(
          title: '11. Limitation of Liability',
          content:
              'In no event shall Dabbler be liable for any indirect, incidental, special, consequential, or punitive damages, including lost profits, arising from your use of the Service.',
        ),

        _buildSection(
          title: '12. Governing Law',
          content:
              'These Terms shall be governed by and construed in accordance with the laws of [Jurisdiction], without regard to its conflict of law provisions.',
        ),

        _buildSection(
          title: '13. Changes to Terms',
          content:
              'We reserve the right to modify these Terms at any time. We will notify users of any changes by posting the new Terms on this page. Your continued use of the Service after changes constitutes acceptance of the new Terms.',
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
                color: Theme.of(context).primaryColor,
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
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.contact_support,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Questions about these Terms?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'If you have any questions about these Terms of Service, please contact us at:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Email: legal@dabbler.com\n'
              'Address: [Company Address]',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _contactSupport,
                child: const Text('Contact Support'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareTerms() {
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
}
