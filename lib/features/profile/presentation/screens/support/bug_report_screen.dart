import 'dart:io' show Platform;

import 'package:dabbler/core/widgets/composer_drawer_kit.dart' show composerType;
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

  /// Field errors, shown only after a submit attempt (as the old Form did).
  String? _emailError;
  String? _titleError;
  String? _descriptionError;
  String? _stepsError;

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
        title: 'Report a Bug',
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
            tone: DabblerBannerTone.warning,
            icon: DabblerIcon('danger', size: 20),
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
          prefixIcon: const DabblerIcon('sms', size: 20),
          errorText: _emailError,
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
          errorText: _titleError,
        ),
        gap,
        DabblerTextField(
          controller: _descriptionController,
          label: 'Detailed Description',
          placeholder: 'Describe what happened and what you expected to happen',
          variant: DabblerTextFieldVariant.multiline,
          rows: 4,
          errorText: _descriptionError,
        ),
        gap,
        DabblerTextField(
          controller: _stepsController,
          label: 'Steps to Reproduce',
          placeholder: '1. Go to...\n2. Click on...\n3. See error',
          variant: DabblerTextFieldVariant.multiline,
          rows: 4,
          errorText: _stepsError,
        ),
      ],
    );
  }

  Widget _buildDeviceInfoSection(BuildContext context) {
    final colors = DabblerColors.of(context);
    final size = MediaQuery.sizeOf(context);
    final lineStyle = composerType(
      context,
      DabblerType.footnote,
      colors.textSecondary,
    );
    return DabblerSection(
      title: 'Additional Information',
      children: [
        DabblerInputRow(
          title: 'Include Device Information',
          subtitle: 'OS version, device model, screen size',
          onTap: () =>
              setState(() => _includeDeviceInfo = !_includeDeviceInfo),
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
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space4,
              DabblerSpacing.space4,
              DabblerSpacing.space4,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device Information to Include:',
                  style: composerType(
                    context,
                    DabblerType.subheadline,
                    colors.textPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: DabblerSpacing.space2),
                Text('• Platform: ${_getPlatformName()}', style: lineStyle),
                Text('• App Version: 1.0.5', style: lineStyle),
                Text('• Flutter Version: 3.x.x', style: lineStyle),
                Text(
                  '• Screen Resolution: ${size.width.toInt()}x${size.height.toInt()}',
                  style: lineStyle,
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

  bool _validate() {
    final email = _emailController.text;
    final description = _descriptionController.text;
    setState(() {
      _emailError = email.isEmpty
          ? 'Please enter your email'
          : (!email.contains('@') ? 'Please enter a valid email' : null);
      _titleError = _titleController.text.isEmpty
          ? 'Please enter a bug title'
          : null;
      _descriptionError = description.isEmpty
          ? 'Please describe the bug'
          : (description.length < 20
                ? 'Please provide more details (at least 20 characters)'
                : null);
      _stepsError = _stepsController.text.isEmpty
          ? 'Please provide steps to reproduce the bug'
          : null;
    });
    return _emailError == null &&
        _titleError == null &&
        _descriptionError == null &&
        _stepsError == null;
  }

  Future<void> _submitBugReport() async {
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
