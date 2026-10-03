import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import '../../../../../core/services/auth_service.dart';
import 'package:dabbler/features/profile/services/data_export_service.dart';
import 'package:dabbler/core/services/analytics/analytics_service.dart';

/// Screen for managing account settings like email, password, and security
class AccountManagementScreen extends ConsumerStatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  ConsumerState<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState
    extends ConsumerState<AccountManagementScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  // Release 2 placeholder: kept for future security settings UI.
  // ignore: unused_field
  bool _isTwoFactorEnabled = false;
  String? _errorMessage;

  // True when the account already has an email/password credential. OAuth-only
  // accounts (Google/Apple) have no password, so they get a "Set Password" flow
  // that doesn't ask for a current password.
  bool _hasPassword = true;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadAccountData();
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

  Future<void> _loadAccountData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Read the email from the live Supabase session so it always reflects
      // the currently signed-in user. currentUserEmailProvider is a cached
      // (non-reactive) Provider and can be stale after switching accounts.
      final currentEmail = _authService.getCurrentUserEmail();

      // Load 2FA status (if available)
      final user = _authService.getCurrentUser();
      final factors = user?.factors ?? [];
      final has2FA = factors.isNotEmpty;

      // Detect whether the account actually has a password set. An "email"
      // identity alone is NOT sufficient — email-OTP accounts have an email
      // identity but no password — so ask the DB directly. Fall back to the
      // identity heuristic only if the RPC is unavailable.
      bool hasPassword;
      try {
        final result = await Supabase.instance.client.rpc(
          'current_user_has_password',
        );
        hasPassword = result == true;
      } catch (_) {
        final identities = user?.identities ?? [];
        hasPassword = identities.any(
          (identity) => identity.provider == 'email',
        );
      }

      if (!mounted) return;
      setState(() {
        _emailController.text = currentEmail ?? '';
        _isTwoFactorEnabled = has2FA;
        _hasPassword = hasPassword;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load account data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toast(String message, DabblerToastTone tone) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: tone));
  }

  @override
  Widget build(BuildContext context) {
    final generalError =
        _errorMessage != null &&
        !_errorMessage!.contains('password') &&
        !_errorMessage!.contains('email');

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Account Management',
        onBack: () => context.pop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DabblerSpacing.space6,
          DabblerSpacing.space4,
          DabblerSpacing.space6,
          DabblerSpacing.space11,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _isLoading
                ? const SizedBox(
                    height: 200,
                    child: Center(child: DabblerSpinner()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (generalError) ...[
                        DabblerBanner(
                          tone: DabblerBannerTone.error,
                          message: _errorMessage,
                          onDismiss: () {
                            setState(() {
                              _errorMessage = null;
                            });
                          },
                        ),
                        const SizedBox(height: DabblerSpacing.space4),
                      ],
                      AccountSecurityIntro(),
                      const SizedBox(height: DabblerSpacing.space7),
                      _buildEmailSection(),
                      const SizedBox(height: DabblerSpacing.space7),
                      _buildPasswordSection(),
                      // KAN-52/KAN-103/P-029: hidden until the export
                      // mechanism covers every data category — see
                      // FeatureFlags.enableDataExport.
                      if (FeatureFlags.enableDataExport) ...[
                        const SizedBox(height: DabblerSpacing.space7),
                        _buildDataExportSection(),
                      ],
                      const SizedBox(height: DabblerSpacing.space7),
                      AccountDangerZone(onDelete: _showDeleteAccountDialog),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailSection() {
    final emailError = _errorMessage != null && _errorMessage!.contains('email')
        ? _errorMessage
        : null;
    return DabblerSection(
      title: 'Email Address',
      children: [
        DabblerTextField(
          controller: _emailController,
          label: 'Email',
          prefixIcon: const DabblerIcon('sms', size: DabblerSizing.iconSm),
          keyboardType: TextInputType.emailAddress,
          errorText: emailError,
        ),
        DabblerButton(
          label: _isSaving ? 'Updating...' : 'Update Email',
          disabled: _isSaving,
          fullWidth: true,
          onPressed: _updateEmail,
        ),
      ],
    );
  }

  Widget _buildPasswordSection() {
    final passwordError =
        _errorMessage != null && _errorMessage!.contains('password')
        ? _errorMessage
        : null;
    return DabblerSection(
      title: _hasPassword ? 'Change Password' : 'Set Password',
      subtitle: _hasPassword
          ? null
          : 'You signed in with Google or Apple. Set a password to also '
                'sign in with your email.',
      children: [
        if (_hasPassword)
          DabblerTextField(
            variant: DabblerTextFieldVariant.password,
            controller: _currentPasswordController,
            label: 'Current Password',
          ),
        DabblerTextField(
          variant: DabblerTextFieldVariant.password,
          controller: _newPasswordController,
          label: 'New Password',
        ),
        DabblerTextField(
          variant: DabblerTextFieldVariant.password,
          controller: _confirmPasswordController,
          label: 'Confirm New Password',
          errorText: passwordError,
        ),
        DabblerButton(
          label: _isSaving
              ? (_hasPassword ? 'Changing...' : 'Setting...')
              : (_hasPassword ? 'Change Password' : 'Set Password'),
          disabled: _isSaving,
          fullWidth: true,
          onPressed: _changePassword,
        ),
      ],
    );
  }

  Widget _buildDataExportSection() {
    final colors = DabblerColors.of(context);
    return DabblerSection(
      children: [
        DabblerInputRow(
          title: 'Export My Data',
          subtitle:
              'Request a copy of your Dabbler data (PDPL data portability)',
          leading: DabblerIcon(
            'document-download',
            size: DabblerSizing.iconMd,
            color: colors.textSecondary,
          ),
          trailing: const DabblerChevron(),
          onTap: _requestDataExport,
        ),
      ],
    );
  }

  Future<void> _requestDataExport() async {
    final user = _authService.getCurrentUser();
    final email = _authService.getCurrentUserEmail();
    if (user == null || email == null) return;

    try {
      await DataExportService().requestGDPRDataExport(
        userId: user.id,
        format: DataExportFormat.json,
        userEmail: email,
      );
      AnalyticsService.trackEvent('data_export_requested', {'format': 'json'});
      if (!mounted) return;
      _toast(
        "We're preparing your data export. You'll be notified by email when it's ready.",
        DabblerToastTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      _toast('Could not request data export: $e', DabblerToastTone.neutral);
    }
  }

  Future<void> _updateEmail() async {
    final newEmail = _emailController.text.trim();

    // Clear previous error messages
    setState(() {
      _errorMessage = null;
    });

    if (newEmail.isEmpty) {
      setState(() {
        _errorMessage = 'email: Email cannot be empty';
      });
      return;
    }

    // Basic email validation
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(newEmail)) {
      setState(() {
        _errorMessage = 'email: Please enter a valid email address';
      });
      return;
    }

    final currentEmail = _authService.getCurrentUserEmail();
    if (newEmail == currentEmail) {
      setState(() {
        _errorMessage = 'email: New email is the same as current email';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Update email in Supabase Auth
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        _toast(
          'Email update request sent. Please check your new email for verification.',
          DabblerToastTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'email: Failed to update email: ${e.toString()}';
        });

        _toast('Failed to update email: $e', DabblerToastTone.error);
      }
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Clear previous error messages
    setState(() {
      _errorMessage = null;
    });

    // Validation. The current password is only required when the account
    // already has one (email/password users); OAuth-only users are setting a
    // password for the first time.
    if (_hasPassword && currentPassword.isEmpty) {
      setState(() {
        _errorMessage = 'password: Please enter your current password';
      });
      return;
    }

    if (newPassword.isEmpty) {
      setState(() {
        _errorMessage = 'password: Please enter a new password';
      });
      return;
    }

    if (newPassword.length < 6) {
      setState(() {
        _errorMessage = 'password: Password must be at least 6 characters long';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'password: Passwords do not match';
      });
      return;
    }

    if (_hasPassword && currentPassword == newPassword) {
      setState(() {
        _errorMessage =
            'password: New password must be different from current password';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final currentEmail = _authService.getCurrentUserEmail();
      if (currentEmail == null) {
        throw Exception('User not authenticated');
      }

      // For existing email/password accounts, verify the current password by
      // re-authenticating before changing it. OAuth-only accounts skip this —
      // they have an active session and no password to verify.
      if (_hasPassword) {
        try {
          await Supabase.instance.client.auth.signInWithPassword(
            email: currentEmail,
            password: currentPassword,
          );
        } catch (e) {
          throw Exception('Current password is incorrect');
        }
      }

      // Update (or set) the password.
      await _authService.updatePassword(newPassword);

      if (mounted) {
        final wasSettingPassword = !_hasPassword;
        setState(() {
          _isSaving = false;
          // The account now has a password, so future visits show "Change".
          _hasPassword = true;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });

        _toast(
          wasSettingPassword
              ? 'Password set. You can now sign in with your email and password.'
              : 'Password updated successfully',
          DabblerToastTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage =
              'password: ${e.toString().replaceAll('Exception: ', '')}';
        });

        _toast('Failed to change password: $e', DabblerToastTone.error);
      }
    }
  }

  // Release 2 placeholder.
  // ignore: unused_element
  Future<void> _toggleTwoFactor(bool enabled) async {
    try {
      if (enabled) {
        // Enable 2FA - Supabase requires TOTP setup
        // For now, show a message that 2FA setup requires additional configuration
        if (mounted) {
          _showInfoDialog(
            'Enable Two-Factor Authentication',
            'Two-factor authentication setup requires additional configuration. '
                'Please use the Supabase dashboard or contact support to enable this feature.',
            onOk: () => setState(() {
              _isTwoFactorEnabled = false;
            }),
          );
        }
      } else {
        // Disable 2FA
        setState(() {
          _isTwoFactorEnabled = false;
        });

        if (mounted) {
          _toast(
            'Two-factor authentication disabled',
            DabblerToastTone.success,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTwoFactorEnabled = !enabled; // Revert the toggle
        });

        _toast('Failed to update 2FA: $e', DabblerToastTone.error);
      }
    }
  }

  // Release 2 placeholder.
  // ignore: unused_element
  void _manageDevices() {
    _showInfoDialog(
      'Manage Devices',
      'Device management allows you to view and revoke access from devices where you\'re logged in. '
          'This feature will be available in a future update.',
    );
  }

  // Release 2 placeholder.
  // ignore: unused_element
  void _viewLoginHistory() {
    _showInfoDialog(
      'Login History',
      'Login history shows recent sign-in activity on your account. '
          'This feature will be available in a future update.',
    );
  }

  void _showInfoDialog(String title, String body, {VoidCallback? onOk}) {
    showDabblerDialog<void>(
      context: context,
      builder: (dialogContext) => DabblerDialog(
        title: title,
        description: body,
        onClose: () => Navigator.of(dialogContext).pop(),
        primaryAction: DabblerDialogAction(
          label: 'OK',
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onOk?.call();
          },
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final confirmTextController = TextEditingController();
    bool isDeleting = false;

    showDabblerDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => DabblerDialog(
          title: 'Delete Account',
          destructive: true,
          dismissible: !isDeleting,
          onClose: isDeleting
              ? null
              : () {
                  confirmTextController.dispose();
                  Navigator.of(context).pop();
                },
          secondaryAction: DabblerDialogAction(
            label: 'Cancel',
            onPressed: isDeleting
                ? () {}
                : () {
                    confirmTextController.dispose();
                    Navigator.of(context).pop();
                  },
          ),
          primaryAction: DabblerDialogAction(
            label: 'Delete Account',
            // While deleting, the button shows its spinner and the dialog
            // cannot be dismissed — the original Material dialog's behaviour.
            loading: isDeleting,
            onPressed: () async {
              if (confirmTextController.text != 'DELETE') {
                DabblerToastProvider.of(context).show(
                  const DabblerToastSpec(
                    message: 'Please type "DELETE" to confirm',
                    tone: DabblerToastTone.error,
                  ),
                );
                return;
              }

              setDialogState(() {
                isDeleting = true;
              });

              try {
                await _deleteAccount();

                if (context.mounted) {
                  confirmTextController.dispose();
                  Navigator.of(context).pop();
                }
              } catch (e) {
                setDialogState(() {
                  isDeleting = false;
                });

                if (context.mounted) {
                  DabblerToastProvider.of(context).show(
                    DabblerToastSpec(
                      message: 'Failed to delete account: $e',
                      tone: DabblerToastTone.error,
                    ),
                  );
                }
              }
            },
          ),
          child: DeleteAccountDialogContent(
            confirmController: confirmTextController,
            enabled: !isDeleting,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      // Permanently delete the auth user. Deleting the auth.users row cascades
      // to all related public/auth data via ON DELETE CASCADE foreign keys.
      // The RPC runs server-side (SECURITY DEFINER) and is scoped to the
      // caller's own account (auth.uid()).
      await Supabase.instance.client.rpc(SupabaseConfig.deleteMyAccountFn);

      // The account no longer exists — clear the local session and leave.
      try {
        await _authService.signOut();
      } catch (_) {
        // Session is already invalid after deletion; ignore.
      }

      if (mounted) {
        // Resolved before navigating: `context.go` replaces the route this
        // context belongs to, so the lookup has to happen while it is still
        // the one the user is on.
        final message = AppLocalizations.of(
          context,
        ).account_delete_success_snack;
        final toasts = DabblerToastProvider.of(context);

        context.go('/auth-welcome');

        toasts.show(
          DabblerToastSpec(message: message, tone: DabblerToastTone.success),
        );
      }
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }
}

/// The "Secure your account" intro at the top of the account screen.
///
/// Public so the render test can pump it without the screen's Supabase
/// session.
class AccountSecurityIntro extends StatelessWidget {
  const AccountSecurityIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Secure your account',
          style: DabblerType.footnote
              .resolveForDirection(Directionality.of(context))
              .copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: DabblerSpacing.space2),
        const DabblerBanner(
          tone: DabblerBannerTone.neutral,
          title: 'Manage credentials & security',
          message:
              'Update your email, password, and security settings to keep your account safe.',
        ),
      ],
    );
  }
}

/// The delete-account row. Public so the render test can pump it.
class AccountDangerZone extends StatelessWidget {
  const AccountDangerZone({super.key, required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DabblerSection(
      children: [
        DabblerInputRow(
          title: 'Delete Account',
          subtitle: 'Permanently delete your account and all data',
          tone: DabblerInputRowTone.destructive,
          leading: const DabblerIcon('trash', size: DabblerSizing.iconMd),
          trailing: const DabblerChevron(),
          onTap: onDelete,
        ),
      ],
    );
  }
}

/// The body of the delete-account confirmation dialog.
///
/// Extracted from [AccountManagementScreen] so KAN-161's AC2 — layout verified
/// at the new string lengths in Arabic as well as English — can be exercised by
/// a widget test against the widget the app actually renders, rather than a
/// reconstruction of it in the test. The screen itself cannot be pumped: it
/// reaches for `Supabase.instance` and an authenticated session.
///
/// The `Type "DELETE"` label is deliberately still a hardcoded English literal.
/// It is outside KAN-160/KAN-161's scope and `content-manager` ruled the
/// confirmation token stays a fixed Latin `DELETE`; see the ticket's scope
/// correction #2.
class DeleteAccountDialogContent extends StatelessWidget {
  const DeleteAccountDialogContent({
    super.key,
    required this.confirmController,
    required this.enabled,
  });

  final TextEditingController confirmController;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocalizations.of(context).account_delete_dialog_warning,
            style: DabblerType.body
                .resolveForDirection(Directionality.of(context))
                .copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: DabblerSpacing.space5),
          DabblerTextField(
            controller: confirmController,
            label: 'Type "DELETE" to confirm',
            prefixIcon: const DabblerIcon(
              'warning-2',
              size: DabblerSizing.iconSm,
            ),
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}
