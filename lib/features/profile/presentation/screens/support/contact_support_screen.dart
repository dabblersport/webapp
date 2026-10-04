import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/profile/presentation/widgets/settings_inner_top_bar.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Screen for contacting the support team — a design-system page: a section
/// of fields (email, category, subject, message) and a send button, under the
/// Settings inner-page header. No design frame exists for this screen; it is a DS-default render.
enum _Category {
  general,
  account,
  technical,
  billing,
  feature,
  abuse,
  privacy,
  other,
}

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

  _Category _selectedCategory = _Category.general;
  bool _isSubmitting = false;

  final _formKey = GlobalKey<FormState>();

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

  String _categoryLabel(AppLocalizations l, _Category c) => switch (c) {
    _Category.general => l.contact_cat_general,
    _Category.account => l.contact_cat_account,
    _Category.technical => l.contact_cat_technical,
    _Category.billing => l.contact_cat_billing,
    _Category.feature => l.contact_cat_feature,
    _Category.abuse => l.contact_cat_abuse,
    _Category.privacy => l.contact_cat_privacy,
    _Category.other => l.contact_cat_other,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerPage(
      topBar: settingsInnerTopBar(context, title: l10n.contact_title),
      // A non-lazy scroll view so every field stays mounted for
      // `Form.validate()`.
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space4,
          DabblerSpacing.space6,
          DabblerSpacing.space10,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DabblerSection(
                title: l10n.contact_section,
                children: [
                  DabblerTextField(
                    controller: _emailController,
                    label: l10n.contact_email,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const DabblerIcon(
                      'sms',
                      size: DabblerSizing.iconRow,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.contact_err_email_required;
                      }
                      if (!value.contains('@')) {
                        return l10n.contact_err_email_invalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: DabblerSpacing.space4),
                  DabblerSelect<_Category>(
                    label: l10n.contact_category,
                    value: _selectedCategory,
                    options: [
                      for (final c in _Category.values)
                        DabblerSelectOption<_Category>(
                          value: c,
                          label: _categoryLabel(l10n, c),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                  ),
                  const SizedBox(height: DabblerSpacing.space4),
                  DabblerTextField(
                    controller: _subjectController,
                    label: l10n.contact_subject,
                    prefixIcon: const DabblerIcon(
                      'document-text',
                      size: DabblerSizing.iconRow,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.contact_err_subject_required;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: DabblerSpacing.space4),
                  DabblerTextField(
                    controller: _messageController,
                    label: l10n.contact_message,
                    variant: DabblerTextFieldVariant.multiline,
                    rows: 5,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.contact_err_message_required;
                      }
                      if (value.length < 10) {
                        return l10n.contact_err_message_short;
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: DabblerSpacing.space7),
              DabblerButton(
                label: l10n.contact_send,
                icon: 'send-2',
                size: DabblerButtonSize.full,
                fullWidth: true,
                loading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submitForm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Future.delayed(DabblerMotion.delayRetryMax);

      if (mounted) {
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(
            message: AppLocalizations.of(context).contact_sent,
            tone: DabblerToastTone.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(
            message: AppLocalizations.of(context).contact_send_failed('$e'),
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
