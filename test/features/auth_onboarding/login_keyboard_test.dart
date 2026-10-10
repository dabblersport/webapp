import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/auth_onboarding/presentation/screens/email_input_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_password_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// With the keyboard open on the login screens the active field is never
/// hidden: only the title, the fields, the primary action (and the code link)
/// stay above the keyboard; the back header and the "or" group wait below it
/// and return when it closes. Renders: `--dart-define=LOGIN_KEYBOARD_DIR=<dir>`.
const String _dir = String.fromEnvironment('LOGIN_KEYBOARD_DIR');
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

class _Phone {
  const _Phone(this.name, this.size, this.keyboard, this.statusBar);
  final String name;
  final Size size;

  /// The top safe area (status bar / notch).
  final double statusBar;

  /// The keyboard's height (iOS: about 291 on a small phone, 336 on a large).
  final double keyboard;
}

const List<_Phone> _phones = <_Phone>[
  // Real iOS keyboards, the Passwords toolbar included, and the top safe area.
  _Phone('se', Size(375, 667), 291, 20),
  _Phone('pro', Size(402, 874), 336, 59),
];

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Locale locale,
  _Phone phone,
) async {
  tester.view.physicalSize = phone.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(tester.view.resetViewInsets);
  tester.view.padding = FakeViewPadding(top: phone.statusBar);
  addTearDown(tester.view.resetPadding);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => RepaintBoundary(
          key: const Key('shot'),
          child: DabblerToastProvider(child: child!),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _keyboard(WidgetTester tester, double height) async {
  tester.view.viewInsets = FakeViewPadding(bottom: height);
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {
  if (_dir.isEmpty) return;
  await tester.runAsync(() async {
    final b =
        tester.renderObject(find.byKey(const Key('shot')))
            as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_dir).createSync(recursive: true);
    File('$_dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

final Finder _backIcon = find.byWidgetPredicate(
  (w) => w is DabblerIcon && w.name == 'arrow-circle-left',
);

Finder _buttonLabelled(String label) =>
    find.byWidgetPredicate((w) => w is DabblerButton && w.label == label);

/// The bottom edge of a widget, to compare with the keyboard's top.
double _bottom(WidgetTester tester, Finder f) => tester.getRect(f.first).bottom;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final String mode = _dark ? 'dark' : 'light';

  for (final phone in _phones) {
    for (final (String dir, Locale locale) in <(String, Locale)>[
      ('en', const Locale('en')),
      ('ar', const Locale('ar')),
    ]) {
      final l = lookupAppLocalizations(locale);

      testWidgets('login: keyboard open keeps title, fields, Log in and the '
          'code link above it - ${phone.name} $dir', (tester) async {
        await _pump(
          tester,
          const EnterPasswordScreen(email: ''),
          locale,
          phone,
        );
        // Closed: the whole screen, back header included.
        expect(_backIcon, findsOneWidget);
        expect(_buttonLabelled(l.auth_entry_continue_google), findsOneWidget);
        await _shoot(tester, 'login-closed-${phone.name}-$dir-$mode');

        await tester.tap(find.byType(EditableText).first);
        await tester.pump();
        await _keyboard(tester, phone.keyboard);
        expect(tester.takeException(), isNull);

        // Back header and the secondary group are out of the way.
        expect(_backIcon, findsNothing);
        expect(_buttonLabelled(l.auth_entry_continue_google), findsNothing);
        expect(find.text(l.auth_new_here), findsNothing);

        // The field being typed in kept its focus through the layout change.
        final EditableText email = tester.widget(
          find.byType(EditableText).first,
        );
        expect(email.focusNode.hasFocus, isTrue);

        // Everything that stays is above the keyboard, fully visible.
        final double top = phone.size.height - phone.keyboard;
        expect(find.text(l.auth_login_title), findsOneWidget);
        expect(_bottom(tester, find.text(l.auth_login_title)), lessThan(top));
        for (final f in <Finder>[
          find.byType(EditableText).at(0),
          find.byType(EditableText).at(1),
          _buttonLabelled(l.auth_login_button),
          find.text(l.auth_login_email_code),
        ]) {
          expect(f, findsOneWidget);
          expect(_bottom(tester, f), lessThanOrEqualTo(top));
          expect(tester.getRect(f).top, greaterThanOrEqualTo(0));
        }
        // The subtitle stays where there is room (Pro) and gives way on the
        // small phone (SE), so nothing is squeezed.
        expect(
          find.text(l.auth_login_subtitle),
          phone.name == 'pro' ? findsOneWidget : findsNothing,
        );
        // Nothing is clipped or overlapped: the fields sit between the title
        // block and the primary action, each in full.
        final Rect e = tester.getRect(find.byType(EditableText).at(0));
        final Rect p = tester.getRect(find.byType(EditableText).at(1));
        final Rect cta = tester.getRect(_buttonLabelled(l.auth_login_button));
        expect(e.bottom, lessThan(p.top));
        expect(p.bottom, lessThanOrEqualTo(cta.top));
        expect(e.top, greaterThan(phone.statusBar));
        await _shoot(tester, 'login-keyboard-${phone.name}-$dir-$mode');

        // Keyboard closed: everything returns.
        await _keyboard(tester, 0);
        expect(_backIcon, findsOneWidget);
        expect(_buttonLabelled(l.auth_entry_continue_google), findsOneWidget);
      });

      testWidgets('sign-up email: keyboard open keeps title, field and the '
          'primary action above it - ${phone.name} $dir', (tester) async {
        await _pump(tester, const EmailInputScreen(), locale, phone);
        expect(_backIcon, findsOneWidget);
        await tester.tap(find.byType(EditableText).first);
        await tester.pump();
        await _keyboard(tester, phone.keyboard);
        expect(tester.takeException(), isNull);
        expect(_backIcon, findsNothing);
        expect(_buttonLabelled(l.auth_entry_continue_google), findsNothing);
        final double top = phone.size.height - phone.keyboard;
        for (final f in <Finder>[
          find.byType(EditableText).first,
          _buttonLabelled(l.auth_email_send_code),
        ]) {
          expect(_bottom(tester, f), lessThanOrEqualTo(top));
        }
        await _shoot(tester, 'signup-keyboard-${phone.name}-$dir-$mode');
        await _keyboard(tester, 0);
        expect(_backIcon, findsOneWidget);
      });
    }
  }
}
