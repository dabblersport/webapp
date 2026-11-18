import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/services/analytics/analytics_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/privacy_toggles.dart';
import 'package:dabbler/features/profile/presentation/widgets/settings/delete_account_sheet_body.dart';
import 'package:dabbler/features/profile/presentation/widgets/settings/settings_top_bar.dart';
import 'package:dabbler/features/profile/services/data_export_service.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/services/auth_service.dart';
import 'account_danger_zone.dart';

part 'account_password_sheet.dart';

/// Account and security — `Settings.dc.html` route `account`: the sign-in rows
/// (email, password), the security switches and the danger zone, with the email
/// and password forms and the delete confirmation in sheets.
class AccountManagementScreen extends ConsumerStatefulWidget {
  const AccountManagementScreen({super.key, this.openPassword = false});

  /// KAN-1003: opens the password change sheet once loaded ("Secure my
  /// account").
  final bool openPassword;

  @override
  ConsumerState<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState
    extends ConsumerState<AccountManagementScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _generalError;
  String? _emailError;
  String? _passwordError;

  // True when the account already has an email/password credential. OAuth-only
  // accounts (Google/Apple) have no password, so they get a "Set Password" flow
  // that doesn't ask for a current password.
  bool _hasPassword = true;

  /// The signed-in email shown on the row, and in the form as the draft.
  String _email = '';

  /// Rebuilds the sheet that is open, if any, so it follows [_isSaving] and the
  /// field errors.
  StateSetter? _sheetSetState;

  final AuthService _authService = AuthService();

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _loadAccountData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        ref
            .read(privacyControllerProvider.notifier)
            .loadPrivacySettings(userId);
      }
    });
  }

  Future<void> _loadAccountData() async {
    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      // Read the email from the live Supabase session so it always reflects
      // the currently signed-in user. currentUserEmailProvider is a cached
      // (non-reactive) Provider and can be stale after switching accounts.
      final currentEmail = _authService.getCurrentUserEmail();
      final user = _authService.getCurrentUser();

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
        _email = currentEmail ?? '';
        _emailController.text = _email;
        _hasPassword = hasPassword;
        _isLoading = false;
      });
      if (widget.openPassword) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showPasswordSheet();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = _l10n.acct_load_failed(e.toString());
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// [setState] for the screen and for the sheet in front of it.
  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    _sheetSetState?.call(() {});
  }

  void _toast(String message, DabblerToastTone tone) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: tone));
  }

  void _closeSheet() {
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(privacyControllerProvider).settings;
    return DabblerPage(
      topBar: settingsTopBar(
        context,
        title: l10n.acct_title,
        onBack: () => context.pop(),
      ),
      body: _isLoading
          ? const Center(child: DabblerSpinner())
          : ListView(
              padding: kSettingsBodyPadding,
              children: [
                if (_generalError != null) ...[
                  DabblerBanner(
                    tone: DabblerBannerTone.error,
                    message: _generalError,
                    onDismiss: () => setState(() => _generalError = null),
                  ),
                  kSettingsGroupGap,
                ],
                DabblerRowGroup(
                  header: l10n.acct_group_signin,
                  children: [
                    DabblerInputRow(
                      flat: true,
                      showDivider: false,
                      leading: settingsRowIcon(context, 'sms'),
                      title: l10n.acct_row_email,
                      value: _email.isEmpty ? null : _email,
                      trailing: _email.isEmpty ? const DabblerChevron() : null,
                      onTap: _showEmailSheet,
                    ),
                    DabblerInputRow(
                      flat: true,
                      showDivider: false,
                      leading: settingsRowIcon(context, 'lock'),
                      title: l10n.acct_row_password,
                      value: _hasPassword ? '••••••••' : null,
                      trailing: _hasPassword ? null : const DabblerChevron(),
                      onTap: _showPasswordSheet,
                    ),
                  ],
                ),
                kSettingsGroupGap,
                // KAN-1003: security notices are always on (CEO), so the
                // "Login alerts" switch is gone; the sign-in list replaces it.
                DabblerRowGroup(
                  header: l10n.acct_group_security,
                  note: l10n.acct_group_security_note,
                  children: [
                    if (settings != null)
                      DabblerInputRow.toggle(
                        flat: true,
                        showDivider: false,
                        leading: settingsRowIcon(context, 'shield-tick'),
                        title: l10n.acct_2fa_title,
                        subtitle: l10n.acct_2fa_sub,
                        checked: settings.twoFactorEnabled,
                        toggleSemanticLabel: l10n.acct_2fa_title,
                        onChanged: (v) => _setSecurity('twoFactorEnabled', v),
                      ),
                    if (FeatureFlags.securityScreens)
                      DabblerInputRow(
                        key: const ValueKey<String>('acct-sign-ins'),
                        flat: true,
                        showDivider: false,
                        leading: settingsRowIcon(context, 'mobile'),
                        title: l10n.sec6_acct_row,
                        subtitle: l10n.sec6_acct_row_sub,
                        trailing: const DabblerChevron(),
                        onTap: () => context.push(RoutePaths.securitySignIns),
                      ),
                  ],
                ),
                // KAN-52/KAN-103/P-029: hidden until the export mechanism
                // covers every data category — see FeatureFlags.enableDataExport.
                if (FeatureFlags.enableDataExport) ...[
                  kSettingsGroupGap,
                  DabblerRowGroup(
                    children: [
                      DabblerInputRow(
                        flat: true,
                        showDivider: false,
                        leading: settingsRowIcon(context, 'document-download'),
                        title: l10n.acct_export_title,
                        subtitle: l10n.acct_export_sub,
                        trailing: const DabblerChevron(),
                        onTap: _requestDataExport,
                      ),
                    ],
                  ),
                ],
                kSettingsGroupGap,
                AccountDangerZone(onDelete: _showDeleteSheet),
              ],
            ),
    );
  }

  /// A security switch applies at once, like every Settings control.
  Future<void> _setSecurity(String key, bool value) async {
    final ctrl = ref.read(privacyControllerProvider.notifier);
    ctrl.updateSetting(key, value);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final saved = await savePrivacyOrRevert(ctrl, userId);
    if (!mounted || saved) return;
    _toast(_l10n.priv_save_failed, DabblerToastTone.error);
  }

  // ─── Email ──────────────────────────────────────────────────────────────

  Future<void> _showEmailSheet() async {
    _emailController.text = _email;
    _emailError = null;
    await showAppSheet<void>(
      context: context,
      title: _l10n.acct_email_sheet_title,
      detent: DabblerSheetDetent.content,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          _sheetSetState = setSheetState;
          final l10n = AppLocalizations.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DabblerTextField(
                controller: _emailController,
                label: l10n.acct_email_field,
                prefixIcon: const DabblerIcon(
                  'sms',
                  size: DabblerSizing.iconSm,
                ),
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
              ),
              const DabblerGap.v(DabblerSpacing.space5),
              DabblerText(
                l10n.acct_email_helper,
                style: DabblerType.caption1,
                tone: DabblerTextTone.secondary,
              ),
              const DabblerGap.v(DabblerSpacing.space5),
              DabblerButton(
                label: _isSaving
                    ? l10n.acct_email_updating
                    : l10n.acct_email_update,
                size: DabblerButtonSize.block,
                disabled: _isSaving,
                onPressed: _updateEmail,
              ),
            ],
          );
        },
      ),
    );
    _sheetSetState = null;
  }

  Future<void> _updateEmail() async {
    final l10n = _l10n;
    final newEmail = _emailController.text.trim();

    _update(() => _emailError = null);

    if (newEmail.isEmpty) {
      _update(() => _emailError = l10n.acct_email_empty);
      return;
    }

    // Basic email validation
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(newEmail)) {
      _update(() => _emailError = l10n.acct_email_invalid);
      return;
    }

    final currentEmail = _authService.getCurrentUserEmail();
    if (newEmail == currentEmail) {
      _update(() => _emailError = l10n.acct_email_same);
      return;
    }

    _update(() {
      _isSaving = true;
      _emailError = null;
    });

    try {
      // Update email in Supabase Auth
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      if (!mounted) return;
      _update(() => _isSaving = false);
      _closeSheet();
      _toast(l10n.acct_email_sent, DabblerToastTone.success);
    } catch (e) {
      if (!mounted) return;
      _update(() {
        _isSaving = false;
        _emailError = l10n.acct_email_failed(e.toString());
      });
      _toast(l10n.acct_email_failed(e.toString()), DabblerToastTone.error);
    }
  }

  // ─── Data export ────────────────────────────────────────────────────────

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
      _toast(_l10n.acct_export_started, DabblerToastTone.success);
    } catch (e) {
      if (!mounted) return;
      _toast(_l10n.acct_export_failed(e.toString()), DabblerToastTone.neutral);
    }
  }

  // ─── Delete ─────────────────────────────────────────────────────────────

  Future<void> _showDeleteSheet() async {
    final confirmTextController = TextEditingController();
    var isDeleting = false;

    await showAppSheet<void>(
      context: context,
      title: _l10n.acct_delete_title,
      detent: DabblerSheetDetent.content,
      showCloseButton: false,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => DeleteAccountSheetBody(
          confirmController: confirmTextController,
          deleting: isDeleting,
          onCancel: () => Navigator.of(sheetContext).pop(),
          onConfirm: () async {
            final l10n = AppLocalizations.of(sheetContext);
            if (confirmTextController.text != 'DELETE') {
              DabblerToastProvider.of(sheetContext).show(
                DabblerToastSpec(
                  message: l10n.acct_delete_type_error,
                  tone: DabblerToastTone.error,
                ),
              );
              return;
            }

            setSheetState(() => isDeleting = true);

            try {
              await _deleteAccount();
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            } catch (e) {
              setSheetState(() => isDeleting = false);
              if (sheetContext.mounted) {
                DabblerToastProvider.of(sheetContext).show(
                  DabblerToastSpec(
                    message: l10n.acct_delete_failed(e.toString()),
                    tone: DabblerToastTone.error,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
    confirmTextController.dispose();
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
