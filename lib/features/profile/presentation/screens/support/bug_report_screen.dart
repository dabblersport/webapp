import 'dart:io' show Platform;

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/profile/presentation/widgets/settings_inner_top_bar.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Screen for reporting bugs and issues — a design-system page: a bug-details
/// section of fields, an additional-information section of toggle rows, and
/// the submit button, under the Settings inner-page header. No design frame exists for
/// this screen; it is a DS-default render.
enum _Severity { low, medium, high, critical }

enum _BugCategory {
  general,
  ui,
  performance,
  crash,
  login,
  profile,
  games,
  notifications,
  social,
  other,
}

class BugReportScreen extends ConsumerStatefulWidget {
  const BugReportScreen({super.key});

  @override
  ConsumerState<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends ConsumerState<BugReportScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  final _emailController = TextEditingController();

  _Severity _selectedSeverity = _Severity.medium;
  _BugCategory _selectedCategory = _BugCategory.general;
  bool _isSubmitting = false;
  bool _includeDeviceInfo = true;
  bool _includeAppLogs = true;

  final _formKey = GlobalKey<FormState>();

  String _severityLabel(AppLocalizations l, _Severity v) => switch (v) {
    _Severity.low => l.bug_sev_low,
    _Severity.medium => l.bug_sev_medium,
    _Severity.high => l.bug_sev_high,
    _Severity.critical => l.bug_sev_critical,
  };

  String _categoryLabel(AppLocalizations l, _BugCategory v) => switch (v) {
    _BugCategory.general => l.bug_cat_general,
    _BugCategory.ui => l.bug_cat_ui,
    _BugCategory.performance => l.bug_cat_performance,
    _BugCategory.crash => l.bug_cat_crash,
    _BugCategory.login => l.bug_cat_login,
    _BugCategory.profile => l.bug_cat_profile,
    _BugCategory.games => l.bug_cat_games,
    _BugCategory.notifications => l.bug_cat_notifications,
    _BugCategory.social => l.bug_cat_social,
    _BugCategory.other => l.bug_cat_other,
  };

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
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerPage(
      topBar: settingsInnerTopBar(context, title: l10n.bug_title),
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
              _buildBugReportForm(),
              const SizedBox(height: DabblerSpacing.space6),
              _buildDeviceInfoSection(context),
              const SizedBox(height: DabblerSpacing.space7),
              DabblerButton(
                label: l10n.bug_submit,
                size: DabblerButtonSize.full,
                fullWidth: true,
                loading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submitBugReport,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBugReportForm() {
    final l10n = AppLocalizations.of(context);
    const gap = SizedBox(height: DabblerSpacing.space4);
    return DabblerSection(
      title: l10n.bug_details,
      children: [
        DabblerTextField(
          controller: _emailController,
          label: l10n.contact_email,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const DabblerIcon('sms', size: DabblerSizing.iconRow),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.bug_err_email_required;
            }
            if (!value.contains('@')) {
              return l10n.contact_err_email_invalid;
            }
            return null;
          },
        ),
        gap,
        DabblerSelect<_BugCategory>(
          label: l10n.bug_category,
          value: _selectedCategory,
          options: [
            for (final c in _BugCategory.values)
              DabblerSelectOption<_BugCategory>(
                value: c,
                label: _categoryLabel(l10n, c),
              ),
          ],
          onChanged: (value) => setState(() => _selectedCategory = value),
        ),
        gap,
        DabblerSelect<_Severity>(
          label: l10n.bug_severity,
          value: _selectedSeverity,
          options: [
            for (final s in _Severity.values)
              DabblerSelectOption<_Severity>(
                value: s,
                label: _severityLabel(l10n, s),
              ),
          ],
          onChanged: (value) => setState(() => _selectedSeverity = value),
        ),
        gap,
        DabblerTextField(
          controller: _titleController,
          label: l10n.bug_field_title,
          placeholder: l10n.bug_field_title_hint,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.bug_err_title_required;
            }
            return null;
          },
        ),
        gap,
        DabblerTextField(
          controller: _descriptionController,
          label: l10n.bug_field_description,
          placeholder: l10n.bug_field_description_hint,
          variant: DabblerTextFieldVariant.multiline,
          rows: 4,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.bug_err_description_required;
            }
            if (value.length < 20) {
              return l10n.bug_err_description_short;
            }
            return null;
          },
        ),
        gap,
        DabblerTextField(
          controller: _stepsController,
          label: l10n.bug_field_steps,
          placeholder: l10n.bug_field_steps_hint,
          variant: DabblerTextFieldVariant.multiline,
          rows: 4,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.bug_err_steps_required;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDeviceInfoSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    return DabblerSection(
      title: l10n.bug_additional,
      children: [
        DabblerInputRow(
          title: l10n.bug_include_device,
          subtitle: l10n.bug_include_device_sub,
          onTap: () => setState(() => _includeDeviceInfo = !_includeDeviceInfo),
          trailing: DabblerToggle(
            checked: _includeDeviceInfo,
            semanticLabel: l10n.bug_include_device,
            onChanged: (value) => setState(() => _includeDeviceInfo = value),
          ),
        ),
        DabblerInputRow(
          title: l10n.bug_include_logs,
          subtitle: l10n.bug_include_logs_sub,
          onTap: () => setState(() => _includeAppLogs = !_includeAppLogs),
          trailing: DabblerToggle(
            checked: _includeAppLogs,
            semanticLabel: l10n.bug_include_logs,
            onChanged: (value) => setState(() => _includeAppLogs = value),
          ),
        ),
        if (_includeDeviceInfo)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: DabblerSpacing.space4,
              top: DabblerSpacing.space4,
              end: DabblerSpacing.space4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DabblerText(
                  l10n.bug_device_heading,
                  style: DabblerType.subheadline,
                  weight: DabblerTextWeight.semibold,
                ),
                const SizedBox(height: DabblerSpacing.space2),
                DabblerText(
                  l10n.bug_device_platform(_getPlatformName(l10n)),
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                ),
                DabblerText(
                  l10n.bug_device_app_version(
                    DabblerType.toWesternDigits(_appVersion),
                  ),
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                ),
                DabblerText(
                  l10n.bug_device_resolution(
                    DabblerType.toWesternDigits(
                      '${size.width.toInt()}x${size.height.toInt()}',
                    ),
                  ),
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                ),
              ],
            ),
          ),
      ],
    );
  }

  static const String _appVersion = '1.7.8';

  String _getPlatformName(AppLocalizations l10n) {
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isLinux) return 'Linux';
      return l10n.bug_platform_unknown;
    } catch (e) {
      return l10n.bug_platform_web;
    }
  }

  Future<void> _submitBugReport() async {
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
            message: AppLocalizations.of(context).bug_submitted,
            tone: DabblerToastTone.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(
            message: AppLocalizations.of(context).bug_submit_failed('$e'),
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
