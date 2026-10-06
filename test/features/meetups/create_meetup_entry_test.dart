/// The Create meet-up entry and drawer, from Home, against
/// `Home Feed.dc.html` (the create menu at `:3357-3361`, the drawer at
/// `:1132-1281`, the Arabic frame at `:2379`).
///
/// * The menu offers the meet-up tile when the flag is on AND the active
///   persona may create (CEO ruling 2026-10-06: player and organiser, not
///   socialiser or host; unknown persona hides it). `can_create_meetup` is not
///   consulted. A server refusal shows in the sheet.
/// * The tiles follow the frame: post / game / meetup, glyphs edit / game /
///   calendar-1 (the dot-grid calendar), plates info / success / accent; the
///   action shows close-circle while the menu is open.
/// * Tapping the tile opens the drawer from Home; its header and CTA sit where
///   the frame measures them, in LTR and RTL.
///
/// Optional define: `CREATE_MEETUP_SHOTS_DIR=<dir>` writes the renders (2x);
/// `SHOT_TAG=<tag>` is appended to every file name (e.g. `dark-after`).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_create_entry.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/home/presentation/screens/home_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_composer_screen.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';

import '../home/home_test_harness.dart';
import 'meetup_screens_harness.dart';

const String _shotsDir = String.fromEnvironment('CREATE_MEETUP_SHOTS_DIR');
const String _shotTag = String.fromEnvironment('SHOT_TAG');
const Key _key = Key('create-meetup-shot');
const double _tol = 0.5;

Future<void> _shoot(WidgetTester tester, String name) async {
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(_key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    final String tag = _shotTag.isEmpty ? '' : '-$_shotTag';
    File(
      '$_shotsDir/$name$tag.png',
    ).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// The frame's four activities (`MEETUP_ACTIVITIES`, `:2812-2817`), as the
/// `sports` table would serve them.
const List<MeetupSport> _frameSports = <MeetupSport>[
  MeetupSport(id: 's1', nameEn: 'Running', nameAr: 'جري', emoji: '\u{1F3C3}'),
  MeetupSport(
    id: 's2',
    nameEn: 'Cycling',
    nameAr: 'ركوب الدراجات',
    emoji: '\u{1F6B4}',
  ),
  MeetupSport(
    id: 's3',
    nameEn: 'Swimming',
    nameAr: 'سباحة',
    emoji: '\u{1F3CA}',
  ),
  MeetupSport(
    id: 's4',
    nameEn: 'Gym',
    nameAr: 'الجيم',
    emoji: '\u{1F3CB}\u{FE0F}',
  ),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Home inside the shell, the meet-up flag on, profile `p1`, and the
/// server check answered by [canCreate].
Future<FakeMeetupRepository> _pumpShell(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Future<bool> Function()? canCreate,
  FakeMeetupRepository? repo,
}) async {
  final FakeMeetupRepository r = (repo ?? FakeMeetupRepository())
    ..sports = _frameSports;
  await pumpHome(
    tester,
    feedState: const FeedLoading(),
    locale: locale,
    boundaryKey: _key,
    inShell: true,
    overrides: <Override>[
      meetupRepositoryProvider.overrideWithValue(r),
      meetupsEnabledProvider.overrideWithValue(true),
      meetupActorProfileIdProvider.overrideWithValue('p1'),
      canCreateMeetupProvider.overrideWith(
        (ref, id) => (canCreate ?? () async => true)(),
      ),
    ],
  );
  await _settle(tester);
  return r;
}

Future<void> _openMenu(WidgetTester tester) async {
  final DabblerNavigationBottomBar bar = tester
      .widget<DabblerNavigationBottomBar>(
        find.byType(DabblerNavigationBottomBar),
      );
  bar.onAction?.call(true);
  await _settle(tester);
}

List<DabblerNavigationCreateItem> _items(WidgetTester tester) => tester
    .widget<DabblerNavigationBottomBar>(find.byType(DabblerNavigationBottomBar))
    .createItems;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });
  final TargetPlatformVariant desktop = TargetPlatformVariant.only(
    TargetPlatform.macOS,
  );

  // CEO ruling 2026-10-06: the tile needs the flag AND a persona that may
  // create (player, organiser). The server's `can_create_meetup` is not asked.
  group('Create meet-up entry: flag and persona rule', () {
    // (case, flag, persona, server answer, offered)
    for (final c
        in <(String, bool, PersonaType?, Future<bool> Function(), bool)>[
          (
            'flag off, player',
            false,
            PersonaType.player,
            () async => true,
            false,
          ),
          ('player', true, PersonaType.player, () async => true, true),
          ('organiser', true, PersonaType.organiser, () async => true, true),
          ('socialiser', true, PersonaType.socialiser, () async => true, false),
          ('host', true, PersonaType.host, () async => true, false),
          ('persona not known yet', true, null, () async => true, false),
          (
            'player, server says no',
            true,
            PersonaType.player,
            () async => false,
            true,
          ),
          (
            'player, check erroring',
            true,
            PersonaType.player,
            () async => throw Failure(code: 'PGRST202', message: 'not found'),
            true,
          ),
        ]) {
      test(c.$1, () async {
        final ProviderContainer container =
            makeContainer(FakeMeetupRepository(), <Override>[
              meetupsEnabledProvider.overrideWithValue(c.$2),
              activePersonaProvider.overrideWithValue(c.$3),
              canCreateMeetupProvider.overrideWith((ref, id) => c.$4()),
            ]);
        container.listen(canOfferCreateMeetupProvider, (_, __) {});
        await Future<void>.delayed(Duration.zero);
        expect(container.read(canOfferCreateMeetupProvider), c.$5);
      });
    }
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final bool rtl = locale.languageCode == 'ar';
    final String dir = rtl ? 'rtl' : 'ltr';

    testWidgets('menu: post, game, meetup as the frame - $dir', (tester) async {
      // The test binding paints box shadows hard-edged
      // (`debugDisableShadows`); the render shows the real soft ones. Reset
      // right after the shot: the binding checks it at the end of the test.
      if (_shotsDir.isNotEmpty) debugDisableShadows = false;
      await _pumpShell(tester, locale: locale);
      await _openMenu(tester);
      await _shoot(tester, 'app-$dir-menu-open');
      debugDisableShadows = true;
      final List<DabblerNavigationCreateItem> items = _items(tester);
      expect(items.map((i) => i.id), <String>['post', 'game', 'meetup']);
      expect(items.map((i) => i.icon), <String>['edit', 'game', 'calendar-1']);
      // `calendar-1` is the frame's dot-grid calendar (plain `calendar` draws
      // a day number in iconsax_flutter), and it resolves to a real glyph.
      expect(
        DabblerIconRegistry.resolve('calendar-1').resolvedKey,
        'calendar_1_copy',
      );
      // The action shows the frame's open glyph: close-circle, upright.
      final DabblerNavigationBottomBar bar = tester
          .widget<DabblerNavigationBottomBar>(
            find.byType(DabblerNavigationBottomBar),
          );
      expect(bar.actionOpenIcon, 'close-circle');
      expect(bar.rotateActionOnOpen, isFalse);
      expect(
        tester
            .widgetList<DabblerIcon>(
              find.descendant(
                of: find.byType(AnimatedRotation),
                matching: find.byType(DabblerIcon),
              ),
            )
            .map((i) => i.name),
        <String>['close-circle'],
      );
      expect(items.map((i) => i.iconTone), <DabblerNavigationIconTone>[
        DabblerNavigationIconTone.info,
        DabblerNavigationIconTone.success,
        DabblerNavigationIconTone.accent,
      ]);
      expect(
        items.map((i) => i.label),
        rtl
            ? <String>['منشور جديد', 'مباراة جديدة', 'لقاء جديد']
            : <String>['Create post', 'Create game', 'Create meetup'],
      );
      // Three tiles on the menu card, left to right in both directions (the
      // frame draws the bar unmirrored).
      final List<Rect> labels = <Rect>[
        for (final DabblerNavigationCreateItem i in items)
          tester.getRect(find.text(i.label)),
      ];
      expect(labels[0].center.dx, lessThan(labels[1].center.dx));
      expect(labels[1].center.dx, lessThan(labels[2].center.dx));
      expect(tester.takeException(), isNull);
    }, variant: desktop);

    testWidgets(
      'menu shows the tile for a player while the check is loading - $dir',
      (tester) async {
        await _pumpShell(
          tester,
          locale: locale,
          canCreate: () => Completer<bool>().future,
        );
        await _openMenu(tester);
        expect(_items(tester).map((i) => i.id), contains('meetup'));
      },
      variant: desktop,
    );

    testWidgets(
      'menu shows the tile for a player when the server says no - $dir',
      (tester) async {
        await _pumpShell(tester, locale: locale, canCreate: () async => false);
        await _openMenu(tester);
        expect(_items(tester).map((i) => i.id), contains('meetup'));
        expect(find.text(_items(tester).last.label), findsOneWidget);
      },
      variant: desktop,
    );

    testWidgets('a server refusal shows the in-sheet message - $dir', (
      tester,
    ) async {
      final FakeMeetupRepository repo = FakeMeetupRepository()
        ..createFailure = const Failure(
          code: 'organiser_required',
          message: 'organiser_required',
        );
      await _pumpShell(
        tester,
        locale: locale,
        repo: repo,
        canCreate: () async => false,
      );
      await _openMenu(tester);
      await tester.tap(find.text(_items(tester).last.label));
      await _settle(tester);
      expect(find.byType(MeetupComposerScreen), findsOneWidget);
      // The place picker is not driven here; give the open drawer a place
      // the way the Home entry would, then submit.
      Navigator.of(tester.element(find.byType(MeetupComposerScreen))).pop();
      await _settle(tester);
      showMeetupComposerSheet(
        tester.element(find.byType(HomeScreen)),
        initialPlace: const ComposerPlacePick(name: 'Kite Beach'),
      );
      await _settle(tester);
      await tester.enterText(find.byType(EditableText).first, 'Sunrise run');
      await tester.pump();
      await tester.ensureVisible(find.byType(DabblerComposerSubmit));
      await tester.tap(find.byType(DabblerComposerSubmit));
      await _settle(tester);
      expect(repo.createCalls, hasLength(1));
      expect(find.byType(MeetupComposerScreen), findsOneWidget);
      expect(
        find.text(
          rtl
              ? 'لا يمكنك إنشاء هذا اللقاء الآن. حاول مرة أخرى لاحقًا.'
              : "You can't create this meet-up right now. Try again later.",
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }, variant: desktop);

    testWidgets('tile opens the drawer from Home, frame geometry - $dir', (
      tester,
    ) async {
      await _pumpShell(tester, locale: locale);
      await _openMenu(tester);
      final String label = _items(tester).last.label;
      await tester.tap(find.text(label));
      await _settle(tester);
      expect(find.byType(MeetupComposerScreen), findsOneWidget);
      expect(find.byType(DabblerSheet), findsOneWidget);
      await _shoot(tester, 'app-$dir-drawer-open');

      // Header (`:1136-1139`): the title starts at the 18 gutter, Cancel ends
      // 18 from the other edge and is the frame's 45 high, its top 46 under
      // the panel's (1px hairline + the 45 grab row).
      final Finder sheet = find.byType(DabblerSheet);
      final Rect panel = tester.getRect(
        find.descendant(of: sheet, matching: find.byType(ClipRRect)).first,
      );
      final String title = rtl ? 'لقاء جديد' : 'Create meet-up';
      final Rect t = tester.getRect(
        find.descendant(of: sheet, matching: find.text(title)).first,
      );
      final Rect cancel = tester.getRect(
        find.widgetWithText(DabblerButton, rtl ? 'إلغاء' : 'Cancel'),
      );
      const double gutter = DabblerSpacing.space6;
      const double width = 393;
      if (rtl) {
        expect(t.right, closeTo(width - gutter, _tol));
        expect(cancel.left, closeTo(gutter, _tol));
      } else {
        expect(t.left, closeTo(gutter, _tol));
        expect(cancel.right, closeTo(width - gutter, _tol));
      }
      expect(cancel.height, closeTo(DabblerSizing.touchTargetMin, _tol));
      expect(
        cancel.top - panel.top,
        closeTo(DabblerSizing.touchTargetMin + DabblerSizing.borderDefault, 1),
      );
      // The sheet is capped at the frame's 94% (`sheetP94`).
      expect(
        panel.height,
        lessThanOrEqualTo(852 * DabblerSheet.contentMaxFractionFull + _tol),
      );
      // Sport tiles: 71 squares, 9 apart (`:1145`).
      final List<Rect> tiles = tester
          .elementList(find.byType(DabblerEmojiTile))
          .map((e) => tester.getRect(find.byElementPredicate((x) => x == e)))
          .toList();
      expect(tiles, hasLength(4));
      expect(tiles.first.width, DabblerEmojiTile.side);
      expect(tiles.first.height, DabblerEmojiTile.side);
      expect(
        (tiles[1].left - tiles[0].right).abs() == DabblerSpacing.space3 ||
            (tiles[0].left - tiles[1].right).abs() == DabblerSpacing.space3,
        isTrue,
      );
      if (rtl) {
        expect(tiles.first.right, closeTo(width - gutter, _tol));
      } else {
        expect(tiles.first.left, closeTo(gutter, _tol));
      }
      // Title field 48, description 96 (`:1151`).
      final List<Rect> fields = tester
          .elementList(find.byType(DabblerComposerField))
          .map((e) => tester.getRect(find.byElementPredicate((x) => x == e)))
          .toList();
      expect(fields[0].height, closeTo(DabblerComposerField.height, _tol));
      expect(
        fields[1].height,
        closeTo(DabblerComposerField.multilineMinHeight, _tol),
      );
      expect(fields[0].width, closeTo(width - 2 * gutter, _tol));

      // The CTA spans the gutters, 48 tall (`:1277`); enabled (a sport is
      // chosen by default, as the frame's Running is).
      await tester.ensureVisible(find.byType(DabblerComposerSubmit));
      await _settle(tester);
      final Rect cta = tester.getRect(find.byType(DabblerComposerSubmit));
      expect(cta.left, closeTo(gutter, _tol));
      expect(cta.width, closeTo(width - 2 * gutter, _tol));
      // The footer block: 1px rule + 12 + the 48 button + 24 = the frame's
      // measured 85 (`:1276-1278`).
      expect(
        cta.height,
        closeTo(
          DabblerSizing.borderDefault +
              DabblerSpacing.space4 +
              DabblerComposerSubmit.height +
              DabblerSpacing.space8,
          _tol,
        ),
      );
      expect(
        tester
            .widget<DabblerComposerSubmit>(find.byType(DabblerComposerSubmit))
            .enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'app-$dir-drawer-cta-enabled');
    }, variant: desktop);

    testWidgets('no sports from the server: in-sheet error, CTA off - $dir', (
      tester,
    ) async {
      final FakeMeetupRepository repo = FakeMeetupRepository()
        ..sportsFailure = const Failure(
          code: '42703',
          message: 'column sports.can_solo does not exist',
        );
      await _pumpShell(tester, locale: locale, repo: repo);
      await _openMenu(tester);
      await tester.tap(find.text(_items(tester).last.label));
      await _settle(tester);
      expect(find.byType(DabblerBanner), findsOneWidget);
      await tester.ensureVisible(find.byType(DabblerComposerSubmit));
      await _settle(tester);
      final DabblerComposerSubmit cta = tester.widget<DabblerComposerSubmit>(
        find.byType(DabblerComposerSubmit),
      );
      expect(cta.enabled, isFalse);
      await tester.tap(find.byType(DabblerComposerSubmit));
      await _settle(tester);
      expect(repo.createCalls, isEmpty);
      expect(find.byType(MeetupComposerScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'app-$dir-drawer-cta-disabled');
    }, variant: desktop);

    testWidgets('missing place is named in place, sheet stays - $dir', (
      tester,
    ) async {
      final FakeMeetupRepository repo = FakeMeetupRepository();
      await _pumpShell(tester, locale: locale, repo: repo);
      await _openMenu(tester);
      await tester.tap(find.text(_items(tester).last.label));
      await _settle(tester);
      await tester.enterText(find.byType(EditableText).first, 'Sunrise run');
      await tester.pump();
      await tester.ensureVisible(find.byType(DabblerComposerSubmit));
      await tester.tap(find.byType(DabblerComposerSubmit));
      await _settle(tester);
      expect(find.byType(MeetupComposerScreen), findsOneWidget);
      expect(
        find.text(
          rtl ? 'أضف موقعًا للقاء.' : 'Add a location for the meet-up.',
        ),
        findsOneWidget,
      );
      expect(repo.createCalls, isEmpty);
      expect(tester.takeException(), isNull);
    }, variant: desktop);

    testWidgets('failed create (no backend) keeps the sheet open - $dir', (
      tester,
    ) async {
      final FakeMeetupRepository repo = FakeMeetupRepository()
        ..createFailure = const Failure(
          code: 'PGRST202',
          message: 'Could not find the function public.rpc_create_meetup',
        );
      await _pumpShell(tester, locale: locale, repo: repo);
      showMeetupComposerSheet(
        tester.element(find.byType(HomeScreen)),
        initialPlace: const ComposerPlacePick(name: 'Kite Beach'),
      );
      await _settle(tester);
      await tester.enterText(find.byType(EditableText).first, 'Sunrise run');
      await tester.pump();
      await tester.ensureVisible(find.byType(DabblerComposerSubmit));
      await tester.tap(find.byType(DabblerComposerSubmit));
      await _settle(tester);
      expect(repo.createCalls, hasLength(1));
      expect(find.byType(MeetupComposerScreen), findsOneWidget);
      expect(
        find.text(rtl ? 'تعذّر إنشاء اللقاء' : 'Failed to create meet-up'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(DabblerComposerSubmit));
      await _settle(tester);
      await _shoot(tester, 'app-$dir-drawer-error');
    }, variant: desktop);

    testWidgets('success closes the sheet and opens the Details - $dir', (
      tester,
    ) async {
      final FakeMeetupRepository repo = FakeMeetupRepository();
      await _pumpShell(tester, locale: locale, repo: repo);
      showMeetupComposerSheet(
        tester.element(find.byType(HomeScreen)),
        initialPlace: const ComposerPlacePick(name: 'Kite Beach'),
      );
      await _settle(tester);
      await tester.enterText(find.byType(EditableText).first, 'Sunrise run');
      await tester.pump();
      await tester.ensureVisible(find.byType(DabblerComposerSubmit));
      await tester.tap(find.byType(DabblerComposerSubmit));
      await _settle(tester);
      expect(repo.createCalls, hasLength(1));
      expect(find.byType(MeetupComposerScreen), findsNothing);
    }, variant: desktop);
  }
}
