import 'package:flutter/material.dart';

class DangerZoneSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<DangerAction> actions;
  final bool showWarningIcon;
  final Color? dangerColor;

  const DangerZoneSection({
    super.key,
    this.title = 'Danger Zone',
    this.subtitle,
    required this.actions,
    this.showWarningIcon = true,
    this.dangerColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = dangerColor ?? Colors.red;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                if (showWarningIcon) ...[
                  Icon(Icons.warning_amber_rounded, color: color, size: 24),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      if (subtitle?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions
          ...actions.asMap().entries.map((entry) {
            final index = entry.key;
            final action = entry.value;

            return Column(
              children: [
                if (index > 0)
                  Divider(
                    height: 1,
                    color: color.withOpacity(0.2),
                    indent: 16,
                    endIndent: 16,
                  ),
                _buildActionTile(context, action, color),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    DangerAction action,
    Color color,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: action.icon != null
          ? Icon(
              action.icon,
              color: action.severity == DangerSeverity.critical
                  ? color
                  : color.withOpacity(0.7),
            )
          : null,
      title: Text(
        action.title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: action.severity == DangerSeverity.critical ? color : null,
        ),
      ),
      subtitle: action.description != null
          ? Text(
              action.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            )
          : null,
      trailing: action.isEnabled
          ? Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: color.withOpacity(0.7),
            )
          : Icon(
              Icons.lock_outline,
              size: 16,
              color: Theme.of(context).disabledColor,
            ),
      onTap: action.isEnabled ? () => _handleAction(context, action) : null,
    );
  }

  void _handleAction(BuildContext context, DangerAction action) {
    if (action.requiresConfirmation) {
      _showConfirmationDialog(context, action);
    } else {
      action.onTap?.call();
    }
  }

  void _showConfirmationDialog(BuildContext context, DangerAction action) {
    final theme = Theme.of(context);
    final color = dangerColor ?? Colors.red;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          action.severity == DangerSeverity.critical
              ? Icons.error_outline
              : Icons.warning_amber_outlined,
          color: color,
          size: 48,
        ),
        title: Text(
          action.confirmationTitle ?? 'Confirm Action',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action.confirmationMessage ??
                  'Are you sure you want to ${action.title.toLowerCase()}?',
              style: theme.textTheme.bodyLarge,
            ),

            if (action.severity == DangerSeverity.critical) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action.warningText ?? 'This action cannot be undone.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (action.requiresTextConfirmation) ...[
              const SizedBox(height: 16),
              Text(
                'Type "${action.confirmationText ?? 'CONFIRM'}" to continue:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _ConfirmationTextField(
                expectedText: action.confirmationText ?? 'CONFIRM',
                onConfirmed: () {
                  Navigator.of(context).pop();
                  action.onTap?.call();
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (!action.requiresTextConfirmation)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                action.onTap?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              child: Text(action.confirmButtonText ?? 'Confirm'),
            ),
        ],
      ),
    );
  }
}

class _ConfirmationTextField extends StatefulWidget {
  final String expectedText;
  final VoidCallback onConfirmed;

  const _ConfirmationTextField({
    required this.expectedText,
    required this.onConfirmed,
  });

  @override
  State<_ConfirmationTextField> createState() => _ConfirmationTextFieldState();
}

class _ConfirmationTextFieldState extends State<_ConfirmationTextField> {
  final _controller = TextEditingController();
  bool _isValid = false;

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
    final isValid = _controller.text.trim() == widget.expectedText;
    if (isValid != _isValid) {
      setState(() => _isValid = isValid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: 'Type ${widget.expectedText}',
            suffixIcon: _isValid
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
          ),
          onSubmitted: _isValid ? (_) => widget.onConfirmed() : null,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isValid ? widget.onConfirmed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ),
      ],
    );
  }
}

enum DangerSeverity { warning, critical }

class DangerAction {
  final String title;
  final String? description;
  final IconData? icon;
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
      icon: Icons.delete_forever,
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
      icon: Icons.clear_all,
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
      icon: Icons.pause_circle_outline,
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
      icon: Icons.lock_reset,
      severity: DangerSeverity.warning,
      requiresConfirmation: false,
      onTap: onReset,
    );
  }

  factory DangerAction.revokeAllSessions({required VoidCallback onRevoke}) {
    return DangerAction(
      title: 'Revoke All Sessions',
      description: 'Log out from all devices',
      icon: Icons.logout,
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

// Compact version for settings pages
class CompactDangerZone extends StatelessWidget {
  final List<DangerAction> actions;
  final Color? dangerColor;

  const CompactDangerZone({super.key, required this.actions, this.dangerColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = dangerColor ?? Colors.red;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Danger Zone',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ...actions.map(
            (action) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(color: color.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: action.icon != null
                    ? Icon(action.icon, color: color, size: 20)
                    : null,
                title: Text(
                  action.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: action.description != null
                    ? Text(
                        action.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.7,
                          ),
                        ),
                      )
                    : null,
                trailing: action.isEnabled
                    ? Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: color.withOpacity(0.7),
                      )
                    : null,
                onTap: action.isEnabled
                    ? () => _handleAction(context, action, color)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, DangerAction action, Color color) {
    if (action.requiresConfirmation) {
      _showConfirmationDialog(context, action, color);
    } else {
      action.onTap?.call();
    }
  }

  void _showConfirmationDialog(
    BuildContext context,
    DangerAction action,
    Color color,
  ) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          action.severity == DangerSeverity.critical
              ? Icons.error_outline
              : Icons.warning_amber_outlined,
          color: color,
          size: 48,
        ),
        title: Text(
          action.confirmationTitle ?? 'Confirm Action',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action.confirmationMessage ??
                  'Are you sure you want to ${action.title.toLowerCase()}?',
              style: theme.textTheme.bodyLarge,
            ),

            if (action.severity == DangerSeverity.critical) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action.warningText ?? 'This action cannot be undone.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (action.requiresTextConfirmation) ...[
              const SizedBox(height: 16),
              Text(
                'Type "${action.confirmationText ?? 'CONFIRM'}" to continue:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _ConfirmationTextField(
                expectedText: action.confirmationText ?? 'CONFIRM',
                onConfirmed: () {
                  Navigator.of(context).pop();
                  action.onTap?.call();
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (!action.requiresTextConfirmation)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                action.onTap?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              child: Text(action.confirmButtonText ?? 'Confirm'),
            ),
        ],
      ),
    );
  }
}
