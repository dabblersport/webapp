import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/profile_sports_screen.dart';
import 'package:dabbler/features/profile/presentation/widgets/manage_sports_sheet.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_sports_view.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show activeSportsByProfileCountryProvider;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/render_mode.dart';

/// Renders the DS sports-preferences screen and the manage-sports sheet (no
/// design frame: DS defaults). Writes PNGs only with
/// `--dart-define=PROFILE_SHOTS_DIR=<dir>`; otherwise it still pumps every
/// state LTR and RTL and checks it renders cleanly.
const String _shotsDir = String.fromEnvironment('PROFILE_SHOTS_DIR');

const Key _shotKey = Key('shot');

Future<void> _shoot(WidgetTester tester, String name) async {
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(_shotKey)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

class _Profile extends StateNotifier<ProfileState>
    implements ProfileController {
  _Profile() : super(const ProfileState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  Locale locale, {
  double height = 852,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileControllerProvider.overrideWith((ref) => _Profile()),
        ...overrides,
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
        home: home,
      ),
    ),
  );
  await _settle(tester);
}

final Map<String, SportPreference> _prefs = {
  'football': const SportPreference(
    name: 'Football',
    emoji: '',
    isEnabled: true,
    skillLevel: SkillLevel.intermediate,
    preferredPosition: 'Midfielder',
  ),
  'padel': const SportPreference(
    name: 'Padel',
    emoji: '',
    isEnabled: true,
    skillLevel: SkillLevel.beginner,
  ),
  'basketball': const SportPreference(
    name: 'Basketball',
    emoji: '',
    isEnabled: false,
    skillLevel: SkillLevel.beginner,
  ),
};

List<String> _positions(String key) => key == 'football'
    ? ['Goalkeeper', 'Defender', 'Midfielder', 'Forward']
    : [];

Widget _view({bool createGame = true}) => ProfileSportsView(
  isLoading: false,
  sportPreferences: _prefs,
  expanded: const {'football'},
  showCreateGame: createGame,
  positionsFor: _positions,
  onBack: () {},
  onSave: () {},
  onCreateGame: () {},
  onToggleExpanded: (_) {},
  onSportEnabledChanged: (_, __, ___) {},
  onSkillLevelSelected: (_, __, ___) {},
  onPositionChanged: (_, __, ___) {},
);

const List<Sport> _sports = [
  Sport(id: '1', nameEn: 'Football', sportKey: 'football'),
  Sport(id: '2', nameEn: 'Padel', sportKey: 'padel'),
  Sport(id: '3', nameEn: 'Basketball', sportKey: 'basketball'),
  Sport(id: '4', nameEn: 'Tennis', sportKey: 'tennis'),
];

void main() {
  setUpAll(loadRenderFonts);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final AppLocalizations l10n = lookupAppLocalizations(locale);

    testWidgets('profile sports view — $dir', (tester) async {
      await _pump(tester, _view(), locale, height: 1500);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.sports_prefs_title), findsOneWidget);
      expect(find.byType(DabblerToggle), findsNWidgets(6));
      expect(find.byType(DabblerChip), findsNWidgets(3));
      expect(find.byType(DabblerSelect<String>), findsOneWidget);
      expect(find.byType(DabblerSportIcon), findsNWidgets(3));
      expect(find.text(l10n.sports_prefs_create_game), findsOneWidget);
      await _shoot(tester, 'profile-sports-$dir');
    });

    testWidgets('profile sports screen without backend — $dir', (tester) async {
      // No Supabase in tests: the load fails and surfaces as a DS toast.
      await _pump(tester, const ProfileSportsScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.sports_prefs_title), findsOneWidget);
      expect(find.text(l10n.sports_prefs_my_sports), findsOneWidget);
      expect(
        find.textContaining(l10n.sports_prefs_load_failed('').replaceAll(RegExp(r'[:：]\s*$'), '')),
        findsOneWidget,
      );
    });

    testWidgets('manage sports sheet — $dir', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => DabblerPage(
            body: Center(
              child: DabblerButton(
                label: 'open',
                onPressed: () => ManageSportsSheet.show(context),
              ),
            ),
          ),
        ),
        locale,
        overrides: [
          activeSportsByProfileCountryProvider.overrideWith(
            (ref) async => _sports,
          ),
        ],
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Manage Sports'), findsOneWidget);
      expect(find.byType(DabblerSearchField), findsOneWidget);
      expect(find.byType(DabblerInputRow), findsNWidgets(4));
      await _shoot(tester, 'manage-sports-sheet-$dir');

      await tester.enterText(find.byType(EditableText), 'pad');
      await _settle(tester);
      expect(find.byType(DabblerInputRow), findsOneWidget);
    });
  }
}
