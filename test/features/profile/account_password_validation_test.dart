// SEC-10: the account password sheet requires at least 8 characters.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dabbler/features/profile/presentation/screens/settings/account_password_validation.dart';
import 'package:dabbler/l10n/app_localizations.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    final l10n = lookupAppLocalizations(locale);

    String? check(String pw) => accountPasswordError(
      l10n,
      hasPassword: false,
      currentPassword: '',
      newPassword: pw,
      confirmPassword: pw,
    );

    test('${locale.languageCode}: 7 characters are rejected', () {
      expect(check('abcdefg'), l10n.acct_password_err_short);
    });

    test('${locale.languageCode}: 8 characters are accepted', () {
      expect(check('abcdefgh'), isNull);
    });
  }

  test('error copy names 8, not 6', () {
    expect(
      lookupAppLocalizations(const Locale('en')).acct_password_err_short,
      contains('8'),
    );
    expect(
      lookupAppLocalizations(const Locale('ar')).acct_password_err_short,
      contains('8'),
    );
  });
}
