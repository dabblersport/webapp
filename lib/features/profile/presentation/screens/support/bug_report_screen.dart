import 'dart:io' show Platform;

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen for reporting bugs and issues — a design-system page: an intro
/// banner, a "Bug Details" section of fields, an "Additional Information"
/// section of toggle rows, and the submit button. No design frame exists for
/// this screen; it is a DS-default render.
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

  String _selectedSeverity = 'Medium';
  String _selectedCategory = 'General Bug';
  bool _isSubmitting = false;
  bool _includeDeviceInfo = true;
  bool _includeAppLogs = true;

  final _formKey = GlobalKey<FormState>();

  final List<String> _severityLevels = ['Low', 'Medium', 'High', 'Critical'];

  final List<String> _categories = [
    'General Bug',
    'UI/Visual Issue',
    'Performance Issue',
    'Crash/Freeze',
    'Login/Authentication',
    'Profile/Settings',
    'Games/Activities',
    'Notifications',
    'Social Features',
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
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        border: true,
        title: 'Report a Bug',
        onBack: () => context.pop(),
      ),
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
              const DabblerBanner(
                tone: DabblerBannerTone.warning,
                icon: DabblerIcon('danger', size: DabblerSizing.iconRow),
                title: 'Found a Bug?',
                message:
                    'Help us improve by reporting any issues you encounter. The more details you provide, the faster we can fix it!',
              ),
              const SizedBox(height: DabblerSpacing.space6),
              _buildBugReportForm(),
              const SizedBox(height: DabblerSpacing.space6),
              _buildDeviceInfoSection(context),
              const SizedBox(height: DabblerSpacing.space7),
              DabblerButton(
                label: 'Submit Bug Report',
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
    const gap = SizedBox(height: DabblerSpacing.space4);
    return DabblerSection(
      title: 'Bug Details',
      children: [
        DabblerTextField(
          controller: _emailController,
          label: 'Your Email',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const DabblerIcon('sms', size: DabblerSizing.iconRow),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        gap,
        DabblerSelect<String>(
          label: 'Bug Category',
          value: _selectedCategory,
          options: [
            for (final c in _categories)
              DabblerSelectOption<String>(value: c, label: c),
          ],
          onChanged: (value) => setState(() => _selectedCategory = value),
        ),
        gap,
        DabblerSelect<String>(
          label: 'Severity Level',
          value: _selectedSeverity,
          options: [
            for (final s in _severityLevels)
              DabblerSelectOption<String>(value: s, label: s),
          ],
          onChanged: (value) => setState(() => _selectedSeverity = value),
        ),
        gap,
        DabblerTextField(
          controller: _titleController,
          label: 'Bug Title',
          placeholder: 'Brief description of the issue',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a bug title';
            }
            return null;
          },
        ),
        gap,
        DabblerTextField(
          controller: _descriptionController,
          label: 'Detailed Description',
          placeholder: 'Describe what happened and what you expected to happen',
          variant: DabblerTextFieldVariant.multiline,
          rows: 4,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please describe the bug';
            }
            if (value.length < 20) {
              return 'Please provide more details (at least 20 characters)';
            }
            return null;
          },
        ),
        gap,
        DabblerTextField(
          controller: _stepsController,
          label: 'Steps to Reproduce',
          placeholder: '1. Go to...\n2. Click on...\n3. See error',
          variant: DabblerTextFieldVariant.multiline,
          rows: 4,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please provide steps to reproduce the bug';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDeviceInfoSection(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return DabblerSection(
      title: 'Additional Information',
      children: [
        DabblerInputRow(
          title: 'Include Device Information',
          subtitle: 'OS version, device model, screen size',
          onTap: () => setState(() => _includeDeviceInfo = !_includeDeviceInfo),
          trailing: DabblerToggle(
            checked: _includeDeviceInfo,
            semanticLabel: 'Include Device Information',
            onChanged: (value) => setState(() => _includeDeviceInfo = value),
          ),
        ),
        DabblerInputRow(
          title: 'Include App Logs',
          subtitle: 'Recent app activity and error logs',
          onTap: () => setState(() => _includeAppLogs = !_includeAppLogs),
          trailing: DabblerToggle(
            checked: _includeAppLogs,
            semanticLabel: 'Include App Logs',
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
                  'Device Information to Include:',
                  style: DabblerType.subheadline,
                  weight: DabblerTextWeight.semibold,
                ),
                const SizedBox(height: DabblerSpacing.space2),
                DabblerText(
                  '• Platform: ${_getPlatformName()}',
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                ),
                const DabblerText(
                  '• App Version: 1.0.5',
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                ),
                const DabblerText(
                  '• Flutter Version: 3.x.x',
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                ),
                DabblerText(
                  '• Screen Resolution: ${size.width.toInt()}x${size.height.toInt()}',
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _getPlatformName() {
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isLinux) return 'Linux';
      return 'Unknown';
    } catch (e) {
      return 'Web';
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
          const DabblerToastSpec(
            message:
                'Bug report submitted successfully! Thank you for helping us improve.',
            tone: DabblerToastTone.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(
            message: 'Failed to submit bug report: $e',
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
