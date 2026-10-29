import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/settings_profiles.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/render_mode.dart';

/// KAN-647: the Settings Profiles group for a one-profile account (contributor,
/// partner) beside a legacy account. Writes PNGs only with
/// `--dart-define=SETTINGS_SHOTS_DIR=<dir>`; otherwise it still pumps every
/// state LTR and RTL and asserts what is, and is not, offered.
const String _shotsDir = String.fromEnvironment('SETTINGS_SHOTS_DIR');
const Key _shotKey = Key('shot');

/// Never touched: the state is preset, so no client call is made.
class _NoClient extends Fake implements SupabaseClient {}

class _FakePersonaService extends PersonaServiceNotifier {
  _FakePersonaService(PersonaState s) : super(_NoClient()) {
    state = s;
  }
}

class _Host extends ConsumerStatefulWidget {
  const _Host();
  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host>
    with SettingsProfilesMixin<_Host> {
  @override
  Widget build(BuildContext context) => DabblerPage(
    body: SingleChildScrollView(child: buildProfileSection(context)),
  );
}

PersonaState _state(PersonaType t) => PersonaState(
  activeProfiles: [ActivePersonaProfile(profileId: 'p1', personaType: t)],
);

Future<void> _shoot(WidgetTester tester, String name) async {
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(_shotKey)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _pump(WidgetTester tester, PersonaState s, Locale locale) async {
  tester.view.physicalSize = const Size(393, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        personaServiceProvider.overrideWith((ref) => _FakePersonaService(s)),
        availableProfilesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: _shotKey, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: const _Host(),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadRenderFonts);

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final l10n = lookupAppLocalizations(locale);

    for (final t in [PersonaType.contributor, PersonaType.partner]) {
      testWidgets('${t.name} sees Edit profile only — $dir', (tester) async {
        await _pump(tester, _state(t), locale);
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.profile_btn_edit), findsOneWidget);
        expect(find.text(l10n.settings_organiser_title), findsNothing);
        expect(find.byType(DabblerInputRow), findsOneWidget);
        await _shoot(tester, 'settings-profiles-${t.name}-$dir');
      });
    }

    testWidgets('a legacy player no longer sees Become an organiser — $dir', (
      tester,
    ) async {
      await _pump(tester, _state(PersonaType.player), locale);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.settings_organiser_title), findsNothing);
      await _shoot(tester, 'settings-profiles-legacy-player-$dir');
    });
  }
}
