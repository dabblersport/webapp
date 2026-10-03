import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen for contacting the support team — a design-system page: an intro
/// banner, a section of fields (email, category, subject, message) and a send
/// button. No design frame exists for this screen; it is a DS-default render.
class ContactSupportScreen extends ConsumerStatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  ConsumerState<ContactSupportScreen> createState() =>
      _ContactSupportScreenState();
}

class _ContactSupportScreenState extends ConsumerState<ContactSupportScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedCategory = 'General';
  bool _isSubmitting = false;

  /// Field errors, shown only after a submit attempt (the old Form validated
  /// on submit the same way).
  String? _emailError;
  String? _subjectError;
  String? _messageError;

  final List<String> _categories = [
    'General',
    'Account Issues',
    'Technical Problem',
    'Payment & Billing',
    'Feature Request',
    'Report Abuse',
    'Privacy Concern',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  void _loadUserEmail() {
    _emailController.text = 'user@example.com';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Contact Support',
        onBack: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space4,
          DabblerSpacing.space6,
          DabblerSpacing.space10,
        ),
        children: [
          const DabblerBanner(
            tone: DabblerBannerTone.info,
            title: 'How can we help?',
            message:
                'Send us a message and we\'ll get back to you as soon as possible.',
          ),
          const SizedBox(height: DabblerSpacing.space6),
          DabblerSection(
            title: 'Contact Information',
            children: [
              DabblerTextField(
                controller: _emailController,
                label: 'Your Email',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const DabblerIcon('sms', size: 20),
                errorText: _emailError,
              ),
              const SizedBox(height: DabblerSpacing.space4),
              DabblerSelect<String>(
                label: 'Category',
                value: _selectedCategory,
                options: [
                  for (final c in _categories)
                    DabblerSelectOption<String>(value: c, label: c),
                ],
                onChanged: (value) =>
                    setState(() => _selectedCategory = value),
              ),
              const SizedBox(height: DabblerSpacing.space4),
              DabblerTextField(
                controller: _subjectController,
                label: 'Subject',
                prefixIcon: const DabblerIcon('document-text', size: 20),
                errorText: _subjectError,
              ),
              const SizedBox(height: DabblerSpacing.space4),
              DabblerTextField(
                controller: _messageController,
                label: 'Message',
                variant: DabblerTextFieldVariant.multiline,
                rows: 5,
                errorText: _messageError,
              ),
            ],
          ),
          const SizedBox(height: DabblerSpacing.space7),
          DabblerButton(
            label: 'Send Message',
            icon: 'send-2',
            size: DabblerButtonSize.full,
            fullWidth: true,
            loading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submitForm,
          ),
        ],
      ),
    );
  }

  bool _validate() {
    final email = _emailController.text;
    final subject = _subjectController.text;
    final message = _messageController.text;
    setState(() {
      _emailError = email.isEmpty
          ? 'Please enter your email'
          : (!email.contains('@') ? 'Please enter a valid email' : null);
      _subjectError = subject.isEmpty ? 'Please enter a subject' : null;
      _messageError = message.isEmpty
          ? 'Please enter your message'
          : (message.length < 10
                ? 'Message must be at least 10 characters long'
                : null);
    });
    return _emailError == null && _subjectError == null && _messageError == null;
  }

  Future<void> _submitForm() async {
    if (!_validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        DabblerToastProvider.of(context).show(
          const DabblerToastSpec(
            message: 'Message sent successfully! We\'ll get back to you soon.',
            tone: DabblerToastTone.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(
            message: 'Failed to send message: $e',
            tone: DabblerToastTone.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
