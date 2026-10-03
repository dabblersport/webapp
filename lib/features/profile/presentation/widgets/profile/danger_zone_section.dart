import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// A titled group of destructive account actions. No design frame (PLAN §2c):
/// DS section, input rows and dialog at their defaults, in the error role.
///
/// KAN-418: `DangerAction.icon` is an Iconsax name for [DabblerIcon] (was
/// `IconData`) and the free `dangerColor` override is gone — the colour is
/// the DS error role. The file had no importers when this changed.
class DangerZoneSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<DangerAction> actions;
  final bool showWarningIcon;

  const DangerZoneSection({
    super.key,
    this.title = 'Danger Zone',
    this.subtitle,
    required this.actions,
    this.showWarningIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.all(DabblerSpacing.space5),
      child: DabblerSurface.card(
        borderColor: colors.error.solid,
        padding: const EdgeInsetsDirectional.all(DabblerSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DangerHeader(
              title: title,
              subtitle: subtitle,
              showWarningIcon: showWarningIcon,
            ),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const DabblerDivider(),
              _DangerRow(action: actions[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _DangerHeader extends StatelessWidget {
  const _DangerHeader({
    required this.title,
    required this.subtitle,
    required this.showWarningIcon,
  });

  final String title;
  final String? subtitle;
  final bool showWarningIcon;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showWarningIcon) ...[
            DabblerIcon(
              'warning-2',
              size: DabblerSizing.iconMd,
              color: colors.error.solid,
            ),
            const SizedBox(width: DabblerSpacing.space4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DabblerType.headline
                      .resolveForDirection(direction)
                      .copyWith(color: colors.error.solid),
                ),
                if (subtitle?.isNotEmpty == true) ...[
                  const SizedBox(height: DabblerSpacing.space1),
                  Text(
                    subtitle!,
                    style: DabblerType.footnote
                        .resolveForDirection(direction)
                        .copyWith(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({required this.action});

  final DangerAction action;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final critical = action.severity == DangerSeverity.critical;
    return DabblerInputRow(
      leading: action.icon != null
          ? DabblerIcon(
              action.icon!,
              size: DabblerSizing.iconMd,
              color: critical ? colors.error.solid : colors.textSecondary,
            )
          : null,
      title: action.title,
      subtitle: action.description,
      trailing: action.isEnabled
          ? DabblerChevron(color: colors.error.solid)
          : DabblerIcon(
              'lock',
              size: DabblerSizing.iconSm,
              color: colors.textTertiary,
            ),
      enabled: action.isEnabled,
      onTap: action.isEnabled ? () => runDangerAction(context, action) : null,
    );
  }
}

/// Runs [action]: straight away, or after its confirmation dialog.
void runDangerAction(BuildContext context, DangerAction action) {
  if (action.requiresConfirmation) {
    showDabblerDialog<void>(
      context: context,
      builder: (_) => _DangerConfirmDialog(action: action),
    );
  } else {
    action.onTap?.call();
  }
}

class _DangerConfirmDialog extends StatefulWidget {
  const _DangerConfirmDialog({required this.action});

  final DangerAction action;

  @override
  State<_DangerConfirmDialog> createState() => _DangerConfirmDialogState();
}

class _DangerConfirmDialogState extends State<_DangerConfirmDialog> {
  final _controller = TextEditingController();
  bool _isValid = false;

  DangerAction get _action => widget.action;
  String get _expected => _action.confirmationText ?? 'CONFIRM';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_checkValidity);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkValidity() {
    final isValid = _controller.text.trim() == _expected;
    if (isValid != _isValid) {
      setState(() => _isValid = isValid);
    }
  }

  void _confirm() {
    Navigator.of(context).pop();
    _action.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final typed = _action.requiresTextConfirmation;
    return DabblerDialog(
      title: _action.confirmationTitle ?? 'Confirm Action',
      description:
          _action.confirmationMessage ??
          'Are you sure you want to ${_action.title.toLowerCase()}?',
      destructive: true,
      onClose: () => Navigator.of(context).pop(),
      secondaryAction: DabblerDialogAction(
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
      primaryAction: DabblerDialogAction(
        label: typed ? 'Confirm' : (_action.confirmButtonText ?? 'Confirm'),
        onPressed: (!typed || _isValid) ? _confirm : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_action.severity == DangerSeverity.critical)
            DabblerBanner(
              tone: DabblerBannerTone.error,
              message: _action.warningText ?? 'This action cannot be undone.',
            ),
          if (typed) ...[
            const SizedBox(height: DabblerSpacing.space5),
            DabblerTextField(
              controller: _controller,
              label: 'Type "$_expected" to continue:',
              placeholder: 'Type $_expected',
              suffixIcon: _isValid ? const DabblerIcon('tick-circle') : null,
              onSubmitted: (_) {
                if (_isValid) _confirm();
              },
            ),
          ],
        ],
      ),
    );
  }
}

enum DangerSeverity { warning, critical }

class DangerAction {
  final String title;
  final String? description;

  /// An Iconsax name for [DabblerIcon], e.g. `'trash'`.
  final String? icon;
  final VoidCallback? onTap;
  final DangerSeverity severity;
  final bool isEnabled;
  final bool requiresConfirmation;
  final bool requiresTextConfirmation;
  final String? confirmationTitle;
  final String? confirmationMessage;
  final String? confirmationText;
  final String? confirmButtonText;
  final String? warningText;

  const DangerAction({
    required this.title,
    this.description,
    this.icon,
    this.onTap,
    this.severity = DangerSeverity.warning,
    this.isEnabled = true,
    this.requiresConfirmation = true,
    this.requiresTextConfirmation = false,
    this.confirmationTitle,
    this.confirmationMessage,
    this.confirmationText,
    this.confirmButtonText,
    this.warningText,
  });

  factory DangerAction.deleteAccount({required VoidCallback onDelete}) {
    return DangerAction(
      title: 'Delete Account',
      description: 'Permanently delete your account and all data',
      icon: 'trash',
      severity: DangerSeverity.critical,
      requiresConfirmation: true,
      requiresTextConfirmation: true,
      confirmationTitle: 'Delete Account',
      confirmationMessage:
          'This will permanently delete your account and all associated data. This action cannot be undone.',
      confirmationText: 'DELETE',
      warningText: 'This action is permanent and cannot be reversed.',
      onTap: onDelete,
    );
  }

  factory DangerAction.clearAllData({required VoidCallback onClear}) {
    return DangerAction(
      title: 'Clear All Data',
      description: 'Remove all your profile data and settings',
      icon: 'broom',
      severity: DangerSeverity.critical,
      requiresConfirmation: true,
      confirmationTitle: 'Clear All Data',
      confirmationMessage:
          'This will remove all your profile data, game history, and settings. You will keep your account but all data will be lost.',
      warningText: 'This action cannot be undone.',
      onTap: onClear,
    );
  }

  factory DangerAction.deactivateAccount({required VoidCallback onDeactivate}) {
    return DangerAction(
      title: 'Deactivate Account',
      description: 'Temporarily deactivate your account',
      icon: 'pause-circle',
      severity: DangerSeverity.warning,
      requiresConfirmation: true,
      confirmationTitle: 'Deactivate Account',
      confirmationMessage:
          'Your account will be hidden from other users. You can reactivate it anytime by logging back in.',
      confirmButtonText: 'Deactivate',
      onTap: onDeactivate,
    );
  }

  factory DangerAction.resetPassword({required VoidCallback onReset}) {
    return DangerAction(
      title: 'Reset Password',
      description: 'Send password reset email',
      icon: 'key',
      severity: DangerSeverity.warning,
      requiresConfirmation: false,
      onTap: onReset,
    );
  }

  factory DangerAction.revokeAllSessions({required VoidCallback onRevoke}) {
    return DangerAction(
      title: 'Revoke All Sessions',
      description: 'Log out from all devices',
      icon: 'logout',
      severity: DangerSeverity.warning,
      requiresConfirmation: true,
      confirmationTitle: 'Revoke All Sessions',
      confirmationMessage:
          'This will log you out from all devices. You will need to log in again.',
      confirmButtonText: 'Revoke All',
      onTap: onRevoke,
    );
  }
}

/// Compact version for settings pages: a warning heading over one bordered
/// row per action.
class CompactDangerZone extends StatelessWidget {
  final List<DangerAction> actions;

  const CompactDangerZone({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DangerHeader(
            title: 'Danger Zone',
            subtitle: null,
            showWarningIcon: true,
          ),
          for (final action in actions)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: DabblerSpacing.space3,
              ),
              child: DabblerSurface.card(
                borderColor: colors.error.solid,
                child: _DangerRow(action: action),
              ),
            ),
        ],
      ),
    );
  }
}
