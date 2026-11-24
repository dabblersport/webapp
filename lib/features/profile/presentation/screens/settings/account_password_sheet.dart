part of 'account_management_screen.dart';

/// The password change / set sheet of [AccountManagementScreen] (KAN-1003:
/// moved out of the screen to keep it under 500 lines).
extension _AccountPasswordSheet on _AccountManagementScreenState {
  // ─── Password ───────────────────────────────────────────────────────────

  Future<void> _showPasswordSheet() async {
    _passwordError = null;
    await showAppSheet<void>(
      context: context,
      title: _hasPassword
          ? _l10n.acct_password_change_title
          : _l10n.acct_password_set_title,
      detent: DabblerSheetDetent.content,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          _sheetSetState = setSheetState;
          final l10n = AppLocalizations.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_hasPassword) ...[
                DabblerText(
                  l10n.acct_password_set_note,
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                ),
                const DabblerGap.v(DabblerSpacing.space4),
              ],
              if (_hasPassword) ...[
                DabblerTextField(
                  variant: DabblerTextFieldVariant.password,
                  controller: _currentPasswordController,
                  label: l10n.acct_password_current,
                  prefixIcon: const DabblerIcon(
                    'lock',
                    size: DabblerSizing.iconSm,
                  ),
                ),
                const DabblerGap.v(DabblerSpacing.space4),
              ],
              DabblerTextField(
                variant: DabblerTextFieldVariant.password,
                controller: _newPasswordController,
                label: l10n.acct_password_new,
                helperText: l10n.acct_password_new_helper,
                prefixIcon: const DabblerIcon(
                  'lock',
                  size: DabblerSizing.iconSm,
                ),
              ),
              const DabblerGap.v(DabblerSpacing.space4),
              DabblerTextField(
                variant: DabblerTextFieldVariant.password,
                controller: _confirmPasswordController,
                label: l10n.acct_password_confirm,
                errorText: _passwordError,
                prefixIcon: const DabblerIcon(
                  'lock',
                  size: DabblerSizing.iconSm,
                ),
              ),
              const DabblerGap.v(DabblerSpacing.space5),
              DabblerButton(
                label: _isSaving
                    ? (_hasPassword
                          ? l10n.acct_password_changing
                          : l10n.acct_password_setting)
                    : (_hasPassword
                          ? l10n.acct_password_change
                          : l10n.acct_password_set),
                size: DabblerButtonSize.full,
                fullWidth: true,
                disabled: _isSaving,
                onPressed: _changePassword,
              ),
              // Clear of the system navigation bar / home indicator.
              SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
            ],
          );
        },
      ),
    );
    _sheetSetState = null;
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  Future<void> _changePassword() async {
    final l10n = _l10n;
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    _update(() => _passwordError = null);

    final error = accountPasswordError(
      l10n,
      hasPassword: _hasPassword,
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    if (error != null) {
      _update(() => _passwordError = error);
      return;
    }

    _update(() {
      _isSaving = true;
      _passwordError = null;
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
          throw Exception(l10n.acct_password_err_incorrect);
        }
      }

      // Update (or set) the password.
      await _authService.updatePassword(newPassword);

      if (!mounted) return;
      final wasSettingPassword = !_hasPassword;
      _update(() {
        _isSaving = false;
        // The account now has a password, so future visits show "Change".
        _hasPassword = true;
      });
      _closeSheet();
      _toast(
        wasSettingPassword
            ? l10n.acct_password_was_set
            : l10n.acct_password_changed,
        DabblerToastTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceAll('Exception: ', '');
      _update(() {
        _isSaving = false;
        _passwordError = message;
      });
      _toast(l10n.acct_password_failed(message), DabblerToastTone.error);
    }
  }
}
