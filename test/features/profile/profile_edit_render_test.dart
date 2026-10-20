import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_edit/profile_edit_availability.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_edit/profile_edit_fields.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_edit/profile_edit_models.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_edit/profile_edit_sports.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// KAN-418 group C: edit profile, danger zone and availability calendar.
/// PNGs go to the Alpha plan folder (override with PROFILE_SHOTS_DIR).
const String _shotsOverride = String.fromEnvironment('PROFILE_SHOTS_DIR');
const String _defaultShots = '$kShotsRoot/profile';

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  Locale locale,
  Key key, {
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: key, child: child),
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  final String dir = _shotsOverride.isEmpty ? _defaultShots : _shotsOverride;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    await Directory(dir).create(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

const _sports = <Sport>[
  Sport(id: 's1', nameEn: 'Football', sportKey: 'football', category: 'team'),
  Sport(
    id: 's2',
    nameEn: 'Basketball',
    sportKey: 'basketball',
    category: 'team',
  ),
  Sport(id: 's3', nameEn: 'Padel', sportKey: 'padel', category: 'racket'),
  Sport(id: 's4', nameEn: 'Tennis', sportKey: 'tennis', category: 'racket'),
  Sport(id: 's5', nameEn: 'Running', sportKey: 'running'),
];

/// The sections below the identity fields, with sample data — the screen's
/// own loader needs a live Supabase session.
class _Sections extends StatelessWidget {
  const _Sections();

  @override
  Widget build(BuildContext context) {
    final selected = <String>{'s1', 's3'};
    return DabblerPage(
      body: ListView(
        padding: const EdgeInsetsDirectional.all(DabblerSpacing.screenGutter),
        children: [
          ProfileEditInterestsSection(
            sportsByCategory: ProfileEditSports.groupByCategory(_sports),
            selectedIds: selected,
            onOpenCategory: (_, _) {},
          ),
          const SizedBox(height: DabblerSpacing.sectionGap),
          ProfileEditSkillLevels(
            entries: const {
              'football': SkillLevel.intermediate,
              'padel': SkillLevel.beginner,
            },
            labelOf: ProfileEditSports.formatSportKey,
            onChanged: (_, _) {},
          ),
          const SizedBox(height: DabblerSpacing.sectionGap),
          ProfileEditAvailabilitySection(
            slots: const [
              ProfileEditTimeSlot(dayOfWeek: 1, startHour: 9, endHour: 17),
              ProfileEditTimeSlot(dayOfWeek: 6, startHour: 18, endHour: 22),
            ],
            onAdd: () {},
            onRemove: (_) {},
          ),
          const SizedBox(height: DabblerSpacing.sectionGap),
          const ProfileEditAvailabilitySection(
            slots: [],
            onAdd: _noop,
            onRemove: _noopInt,
          ),
          const SizedBox(height: DabblerSpacing.sectionGap),
          ProfileEditDobField(
            value: DateTime(1995, 4, 12),
            minimum: DateTime(1926),
            maximum: DateTime(2013),
            onOpenPicker: () {},
            onChanged: (_) {},
          ),
          const SizedBox(height: DabblerSpacing.sectionGap),
          ProfileEditCategorySportsSheet(
            sports: _sports.take(2).toList(),
            isSelected: (s) => selected.contains(s.id),
            isPrimary: (s) => s.id == 's1',
            isPreferred: (_) => false,
            onToggle: (_, _) {},
          ),
        ],
      ),
    );
  }
}

void _noop() {}
void _noopInt(int _) {}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('profile edit screen top — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const ProfileEditScreen(), locale, key);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(lookupAppLocalizations(locale).profile_btn_edit), findsOneWidget);
      await _shoot(tester, key, 'profile-edit-top-$dir');
    });

    testWidgets('profile edit sections — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(
        tester,
        const _Sections(),
        locale,
        key,
        size: const Size(393, 2000),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Interests'), findsOneWidget);
      expect(find.text('Skill Levels'), findsOneWidget);
      expect(find.text('Weekly Availability'), findsNWidgets(2));
      expect(find.byType(DabblerSelect<SkillLevel>), findsNWidgets(2));
      await _shoot(tester, key, 'profile-edit-sections-$dir');
    });

    testWidgets('profile edit avatar header — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(
        tester,
        DabblerPage(
          body: ListView(
            padding: const EdgeInsets.all(DabblerSpacing.screenGutter),
            children: [
              ProfileEditAvatarHeader(
                avatarUrl: 'ds:profile:draft:user:u1:gen:0:option:1',
                displayName: 'Layla',
                uploading: false,
                onTap: () {},
              ),
              const SizedBox(height: DabblerSpacing.space8),
              ProfileEditAvatarHeader(
                avatarUrl: null,
                displayName: 'Layla',
                uploading: true,
                onTap: () {},
              ),
            ],
          ),
        ),
        locale,
        key,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerAvatar), findsNWidgets(2));
      await _shoot(tester, key, 'profile-edit-avatar-$dir');
    });
  }
}
