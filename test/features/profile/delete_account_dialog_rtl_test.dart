// KAN-161 AC2: layout verified at the new string lengths, in Arabic as well as
// English.
//
// This pumps `DeleteAccountDialogContent` — the widget the app actually renders
// inside the delete-account confirmation dialog — rather than a reconstruction
// of it, so a regression in the screen fails this test. `AccountManagementScreen`
// itself cannot be pumped: it reaches for `Supabase.instance` and an
// authenticated session in `initState`.
//
// The expected strings are written out in full rather than read back through
// `AppLocalizations`, which would be circular. They are copied from
// `lib/l10n/app_en.arb` and `app_ar.arb` as supplied by KAN-160, so this also
// pins AC1's "no re-wording during wiring".

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/account_management_screen.dart';

const _enWarning =
    'This action cannot be undone. Your profile and personal data are deleted. '
    'Payment and booking records are retained for accounting purposes, for a '
    'period that is still being finalized.';
const _arWarning =
    'الخطوة دي مفيش رجوع فيها. بنمسح بياناتك الشخصية وملفك الشخصي. سجلات الدفع '
    'والحجز بنحتفظ بيها لأغراض محاسبية، ومدة الاحتفاظ لسه بتتحدد.';

const _enSuccessSnack = 'Your account and personal data have been deleted.';
const _arSuccessSnack = 'تم حذف حسابك وبياناتك الشخصية.';

Widget _harness({required Locale locale, required TextEditingController c}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: AlertDialog(
        title: const Text('Delete Account'),
        content: DeleteAccountDialogContent(
          confirmController: c,
          enabled: true,
        ),
      ),
    ),
  );
}

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  group('delete-account dialog renders the KAN-160 warning', () {
    testWidgets('in English, with no overflow', (tester) async {
      await tester.pumpWidget(_harness(locale: const Locale('en'), c: controller));
      await tester.pumpAndSettle();

      expect(find.text(_enWarning), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in Arabic, with no overflow', (tester) async {
      await tester.pumpWidget(_harness(locale: const Locale('ar'), c: controller));
      await tester.pumpAndSettle();

      expect(find.text(_arWarning), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays the Arabic string out right-to-left', (tester) async {
      await tester.pumpWidget(_harness(locale: const Locale('ar'), c: controller));
      await tester.pumpAndSettle();

      // Arabic is RTL and that changes layout — this is the half of AC2 that a
      // string-presence assertion alone would not catch.
      final direction = Directionality.of(
        tester.element(find.text(_arWarning)),
      );
      expect(direction, TextDirection.rtl);
    });

    testWidgets('in Arabic at a narrow phone width, with no overflow', (
      tester,
    ) async {
      // 360dp is the tight case: the AR warning is the longest string in the
      // dialog, and a RenderFlex overflow here would be a real broken screen.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(locale: const Locale('ar'), c: controller));
      await tester.pumpAndSettle();

      expect(find.text(_arWarning), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('KAN-160 strings resolve through AppLocalizations', () {
    testWidgets('both keys, both locales, exactly as supplied', (tester) async {
      for (final (locale, warning, snack) in [
        (const Locale('en'), _enWarning, _enSuccessSnack),
        (const Locale('ar'), _arWarning, _arSuccessSnack),
      ]) {
        late AppLocalizations l10n;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(l10n.account_delete_dialog_warning, warning);
        // The success snackbar is wired at account_management_screen.dart:1175
        // and is not rendered by the dialog, so it is pinned here instead.
        expect(l10n.account_delete_success_snack, snack);
      }
    });
  });
}
