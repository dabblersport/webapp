import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/authentication/presentation/providers/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Header
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(child: _buildHeader(context)),
            ),
            // Hero Card
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              sliver: SliverToBoxAdapter(child: _buildHeroCard(context)),
            ),
            // Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountSection(context),
                    const SizedBox(height: 20),
                    _buildPrivacySection(context),
                    const SizedBox(height: 20),
                    _buildGeneralSection(context),
                    const SizedBox(height: 20),
                    _buildSupportSection(context),
                    const SizedBox(height: 20),
                    _buildAboutSection(context),
                  ],
                ),
              ),
            ),
          ],
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
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Icons.dashboard_rounded),
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
                'Settings',
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
            'Customize your experience',
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
            'Preferences & controls',
            style: textTheme.headlineSmall?.copyWith(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Manage your account, privacy, and app settings all in one place.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return _buildSettingsCard(context, 'Account', [
      _buildSettingItem(
        context,
        'Profile Information',
        'Update your personal details',
        Icons.person_outlined,
        () {
          context.push('/edit_profile');
        },
      ),
      _buildSettingItem(
        context,
        'Password & Security',
        'Change password and security settings',
        Icons.shield_outlined,
        () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔐 Password & Security - Coming soon!'),
            ),
          );
        },
      ),
      _buildSettingItem(
        context,
        'Connected Accounts',
        'Manage social media connections',
        Icons.link,
        () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔗 Connected Accounts - Link your social media!'),
            ),
          );
        },
      ),
    ]);
  }

  Widget _buildPrivacySection(BuildContext context) {
    return _buildSettingsCard(context, 'Privacy & Security', [
      _buildSwitchItem(
        context,
        'Location Services',
        'Allow app to access your location',
        Icons.location_city_outlined,
        true,
        (value) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value
                    ? '📍 Location services enabled!'
                    : '📍 Location services disabled!',
              ),
            ),
          );
        },
      ),
      _buildSwitchItem(
        context,
        'Profile Visibility',
        'Make your profile visible to others',
        Icons.visibility_outlined,
        true,
        (value) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value
                    ? '👁️ Profile is now visible to others!'
                    : '👁️ Profile is now private!',
              ),
            ),
          );
        },
      ),
      _buildSettingItem(
        context,
        'Data & Privacy',
        'Manage your data and privacy settings',
        Icons.storage_outlined,
        () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗃️ Data & Privacy settings - Coming soon!'),
            ),
          );
        },
      ),
    ]);
  }

  Widget _buildGeneralSection(BuildContext context) {
    final items = <Widget>[
      if (FeatureFlags.enablePayments)
        _buildSettingItem(
          context,
          'Payment Methods',
          'Manage your payment cards and methods',
          Icons.credit_card_outlined,
          () {
            context.push('/payment_methods');
          },
        ),
      _buildSettingItem(
        context,
        'Language',
        'Choose your preferred language',
        Icons.language_outlined,
        () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🌍 Language: English (Arabic coming soon!)'),
            ),
          );
        },
      ),
      _buildSettingItem(
        context,
        'Theme & Appearance',
        'Switch between light and dark mode',
        Icons.palette_outlined,
        () {
          context.push('/theme_settings');
        },
      ),
    ];

    return _buildSettingsCard(context, 'General', items);
  }

  Widget _buildSupportSection(BuildContext context) {
    return _buildSettingsCard(context, 'Support', [
      _buildSettingItem(
        context,
        'Help & Support',
        'Get help and contact support',
        Icons.help_outline,
        () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('💬 Help & Support - FAQ available soon!'),
            ),
          );
        },
      ),
      _buildSettingItem(
        context,
        'Report a Problem',
        'Report bugs or issues',
        Icons.flag_outlined,
        () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚩 Report Problem - Thank you for feedback!'),
            ),
          );
        },
      ),
      _buildSettingItem(
        context,
        'Contact Us',
        'Get in touch with our team',
        Icons.email_outlined,
        () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📧 Contact: support@dabbler.app')),
          );
        },
      ),
    ]);
  }

  Widget _buildAboutSection(BuildContext context) {
    return _buildSettingsCard(context, 'About', [
      _buildSettingItem(
        context,
        'App Information',
        'Version, terms, and privacy policy',
        Icons.info_outline,
        () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ℹ️ App Version: 1.0.5 Beta')),
          );
        },
      ),
      _buildSettingItem(
        context,
        'Terms of Service',
        'Read our terms and conditions',
        Icons.description_outlined,
        () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '📄 Terms of Service - Legal document coming soon!',
              ),
            ),
          );
        },
      ),
      _buildSettingItem(
        context,
        'Privacy Policy',
        'Learn how we protect your data',
        Icons.shield_outlined,
        () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🛡️ Privacy Policy - We protect your data!'),
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      _buildSignOutItem(context),
    ]);
  }

  Widget _buildSignOutItem(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.logout_outlined, size: 20, color: Colors.red),
      ),
      title: Text(
        'Sign Out',
        style: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.red,
        ),
      ),
      subtitle: Text(
        'Sign out of your account',
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.red.withOpacity(0.7),
      ),
      onTap: () => _showSignOutDialog(context),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.logout_rounded, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Sign Out',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to sign out?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ll need to sign in again to access your account.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Signing out...'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.blue,
                  ),
                );

                try {
                  await AuthService().signOut();
                  // Proactively notify router (legacy screen not using SimpleAuthNotifier)
                  try {
                    routerRefreshNotifier.notifyAuthStateChanged();
                  } catch (_) {}

                  if (context.mounted) {
                    // Navigate to primary auth entry (phone input)
                    context.go(RoutePaths.phoneInput);

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text('Signed out successfully'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              Icons.error_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text('Error signing out: ${e.toString()}'),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
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
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}
