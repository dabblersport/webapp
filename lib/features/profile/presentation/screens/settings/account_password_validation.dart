import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Validates the account password sheet's fields (SEC-10). Returns the
/// localized error to show, or `null` when the input may be submitted.
String? accountPasswordError(
  AppLocalizations l10n, {
  required bool hasPassword,
  required String currentPassword,
  required String newPassword,
  required String confirmPassword,
}) {
  // The current password is only required when the account already has one
  // (email/password users); OAuth-only users are setting one for the first time.
  if (hasPassword && currentPassword.isEmpty) {
    return l10n.acct_password_err_current;
  }
  if (newPassword.isEmpty) return l10n.acct_password_err_new;
  if (newPassword.length < SupabaseConfig.minPasswordLength) {
    return l10n.acct_password_err_short;
  }
  if (newPassword != confirmPassword) return l10n.acct_password_err_mismatch;
  if (hasPassword && currentPassword == newPassword) {
    return l10n.acct_password_err_same;
  }
  return null;
}
