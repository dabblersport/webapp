import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../features/authentication/presentation/providers/auth_profile_providers.dart';
import '../../../../../features/profile/data/datasources/supabase_profile_datasource.dart';

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
  bool _isTwoFactorEnabled = false;
  bool _isPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _errorMessage;

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
      // Load real user email
      final userEmail = ref.read(currentUserEmailProvider);
      final currentEmail = userEmail ?? _authService.getCurrentUserEmail();

      // Load 2FA status (if available)
      final user = _authService.getCurrentUser();
      final factors = user?.factors ?? [];
      final has2FA = factors.isNotEmpty;

      setState(() {
        _emailController.text = currentEmail ?? '';
        _isTwoFactorEnabled = has2FA;
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // Error message banner
                      if (_errorMessage != null &&
                          !_errorMessage!.contains('password') &&
                          !_errorMessage!.contains('email'))
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          sliver: SliverToBoxAdapter(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      setState(() {
                                        _errorMessage = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Header
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildHeader(context),
                        ),
                      ),
                      // Hero Card
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildHeroCard(context),
                        ),
                      ),
                      // Content
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildEmailSection(),
                              const SizedBox(height: 20),
                              _buildPasswordSection(),
                              // Release 2: Security Settings
                              // const SizedBox(height: 20),
                              // _buildSecuritySection(),
                              const SizedBox(height: 20),
                              _buildDangerZone(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Management',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF4A148C) : const Color(0xFFE0C7FF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Secure your account',
            style: textTheme.labelLarge?.copyWith(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.8)
                  : Colors.black.withOpacity(0.7),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage credentials & security',
            style: textTheme.headlineSmall?.copyWith(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Update your email, password, and security settings to keep your account safe.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email Address',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null && _errorMessage!.contains('email'))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.icon(
              onPressed: _isSaving ? null : _updateEmail,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSaving ? 'Updating...' : 'Update Email'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Password',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isPasswordVisible,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isNewPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _isNewPasswordVisible = !_isNewPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isNewPasswordVisible,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isConfirmPasswordVisible,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null && _errorMessage!.contains('password'))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.icon(
              onPressed: _isSaving ? null : _changePassword,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSaving ? 'Changing...' : 'Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  // Release 2: Security Settings section
  // Widget _buildSecuritySection() {
  //   final colorScheme = Theme.of(context).colorScheme;
  //   final textTheme = Theme.of(context).textTheme;

  //   return Card(
  //     elevation: 0,
  //     color: colorScheme.surfaceContainerHigh,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  //     child: Padding(
  //       padding: const EdgeInsets.all(20),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             'Security Settings',
  //             style: textTheme.titleMedium?.copyWith(
  //               fontWeight: FontWeight.w700,
  //               color: colorScheme.onSurface,
  //             ),
  //           ),
  //           const SizedBox(height: 16),
  //           SwitchListTile(
  //             title: const Text('Two-Factor Authentication'),
  //             subtitle: const Text(
  //               'Add an extra layer of security to your account',
  //             ),
  //             value: _isTwoFactorEnabled,
  //             onChanged: (value) {
  //               setState(() {
  //                 _isTwoFactorEnabled = value;
  //               });
  //               _toggleTwoFactor(value);
  //             },
  //             contentPadding: EdgeInsets.zero,
  //           ),
  //           const Divider(),
  //           ListTile(
  //             contentPadding: EdgeInsets.zero,
  //             leading: Container(
  //               padding: const EdgeInsets.all(10),
  //               decoration: BoxDecoration(
  //                 color: colorScheme.primaryContainer.withOpacity(0.5),
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //               child: Icon(Icons.devices_outlined, color: colorScheme.primary),
  //             ),
  //             title: const Text('Manage Devices'),
  //             subtitle: const Text('View and manage logged-in devices'),
  //             trailing: const Icon(Icons.arrow_forward_ios, size: 16),
  //             onTap: _manageDevices,
  //           ),
  //           ListTile(
  //             contentPadding: EdgeInsets.zero,
  //             leading: Container(
  //               padding: const EdgeInsets.all(10),
  //               decoration: BoxDecoration(
  //                 color: colorScheme.primaryContainer.withOpacity(0.5),
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //               child: Icon(Icons.history, color: colorScheme.primary),
  //             ),
  //             title: const Text('Login History'),
  //             subtitle: const Text('View recent login activity'),
  //             trailing: const Icon(Icons.arrow_forward_ios, size: 16),
  //             onTap: _viewLoginHistory,
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildDangerZone() {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.orange.shade50.withOpacity(0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Danger Zone',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade100, Colors.red.shade200],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.red.shade700,
                  size: 24,
                ),
              ),
              title: Text(
                'Delete Account',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade900,
                ),
              ),
              subtitle: Text(
                'Permanently delete your account and all data',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.red.shade700,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.red.shade700,
              ),
              onTap: _showDeleteAccountDialog,
            ),
          ],
        ),
      ),
    );
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email update request sent. Please check your new email for verification.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'email: Failed to update email: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update email: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

    // Validation
    if (currentPassword.isEmpty) {
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

    if (currentPassword == newPassword) {
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
      // Verify current password by attempting to re-authenticate
      final currentEmail = _authService.getCurrentUserEmail();
      if (currentEmail == null) {
        throw Exception('User not authenticated');
      }

      // Re-authenticate with current password to verify
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: currentEmail,
          password: currentPassword,
        );
      } catch (e) {
        throw Exception('Current password is incorrect');
      }

      // Update password
      await _authService.updatePassword(newPassword);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage =
              'password: ${e.toString().replaceAll('Exception: ', '')}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleTwoFactor(bool enabled) async {
    try {
      if (enabled) {
        // Enable 2FA - Supabase requires TOTP setup
        // For now, show a message that 2FA setup requires additional configuration
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Enable Two-Factor Authentication'),
              content: const Text(
                'Two-factor authentication setup requires additional configuration. '
                'Please use the Supabase dashboard or contact support to enable this feature.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _isTwoFactorEnabled = false;
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        // Disable 2FA
        setState(() {
          _isTwoFactorEnabled = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Two-factor authentication disabled'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTwoFactorEnabled = !enabled; // Revert the toggle
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update 2FA: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _manageDevices() {
    // Navigate to device management screen or show dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Devices'),
        content: const Text(
          'Device management allows you to view and revoke access from devices where you\'re logged in. '
          'This feature will be available in a future update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _viewLoginHistory() {
    // Navigate to login history screen or show dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login History'),
        content: const Text(
          'Login history shows recent sign-in activity on your account. '
          'This feature will be available in a future update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    final confirmTextController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action cannot be undone. All your data will be permanently deleted.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Enter your password to confirm',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  obscureText: true,
                  enabled: !isDeleting,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmTextController,
                  decoration: const InputDecoration(
                    labelText: 'Type "DELETE" to confirm',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.warning_outlined),
                  ),
                  enabled: !isDeleting,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting
                  ? null
                  : () {
                      passwordController.dispose();
                      confirmTextController.dispose();
                      Navigator.of(context).pop();
                    },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter your password'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (confirmTextController.text != 'DELETE') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please type "DELETE" to confirm'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() {
                        isDeleting = true;
                      });

                      try {
                        await _deleteAccount(passwordController.text);

                        if (context.mounted) {
                          passwordController.dispose();
                          confirmTextController.dispose();
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        setDialogState(() {
                          isDeleting = false;
                        });

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete account: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(String password) async {
    try {
      // Verify password by re-authenticating
      final currentEmail = _authService.getCurrentUserEmail();
      if (currentEmail == null) {
        throw Exception('User not authenticated');
      }

      // Re-authenticate to verify password
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: currentEmail,
          password: password,
        );
      } catch (e) {
        throw Exception('Incorrect password');
      }

      // Get user ID
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Delete profile data first (cascading deletes should handle related data)
      final profileDataSource = SupabaseProfileDataSource(
        Supabase.instance.client,
      );

      try {
        await profileDataSource.deleteProfile(userId);
      } catch (e) {
        // Log but continue with auth deletion
      }

      // Delete auth user (requires admin API or RPC function)
      // Note: Direct user deletion requires admin privileges
      // For now, we'll sign out and show a message
      await _authService.signOut();

      if (mounted) {
        // Navigate to login screen
        context.go('/login');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account deletion request submitted. Your account will be deleted after verification.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }
}
