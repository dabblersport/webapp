import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_create_entry.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_composer_screen.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dabbler/l10n/app_localizations.dart';

import 'meetup_screens_harness.dart';

Future<FakeMeetupRepository> _open(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  ValueChanged<String>? onCreated,
  FakeMeetupRepository? repo,
}) async {
  final r = repo ?? FakeMeetupRepository();
  await pumpMeetups(
    tester,
    // The drawer's body scrolls inside the DS sheet; standalone it needs a
    // scroller of its own.
    SingleChildScrollView(
      child: MeetupComposerScreen(
        onCreated: onCreated,
        initialDate: DateTime(2030, 1, 15),
        initialStart: const TimeOfDay(hour: 18, minute: 0),
        initialPlace: const ComposerPlacePick(name: 'Kite Beach'),
      ),
    ),
    r,
    locale: locale,
  );
  // The test font (Ahem) is wider than the real one, so the three When pills
  // overflow their row here; the real-font render shows them fitting.
  tester.takeException();
  return r;
}

Future<void> _fill(WidgetTester tester) async {
  // The first tile (Running; جري in Arabic, from `name_ar`).
  await tester.tap(find.byType(DabblerEmojiTile).first);
  await tester.pump();
  await tester.enterText(find.byType(EditableText).first, 'Sunrise run');
  await tester.pump();
}

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;
    testWidgets('default state: CTA live with a sport; empty title is named '
        'in place ($tag)', (tester) async {
      final repo = await _open(tester, locale: locale);
      expect(
        find.text(tag == 'ar' ? 'لقاء جديد' : 'Create meet-up'),
        findsWidgets,
      );
      // The frame's rule (`meetupCtaBg`): live once an activity is chosen,
      // and the first sport is chosen on open.
      expect(
        tester
            .widget<DabblerComposerSubmit>(find.byType(DabblerComposerSubmit))
            .enabled,
        isTrue,
      );
      await tester.ensureVisible(find.byType(DabblerComposerSubmit));
      await tester.tap(find.byType(DabblerComposerSubmit));
      await settle(tester);
      expect(repo.createCalls, isEmpty);
      expect(
        find.text(
          tag == 'ar'
              ? lookupAppLocalizations(locale).meetups_err_title_invalid
              : 'The title must be 3 to 80 characters.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('filled form sends the RPC params ($tag)', (tester) async {
      String? created;
      final repo = await _open(
        tester,
        locale: locale,
        onCreated: (id) => created = id,
      );
      await _fill(tester);
      await tester.ensureVisible(find.byType(DabblerComposerSubmit));
      await tester.tap(find.byType(DabblerComposerSubmit));
      await settle(tester);
      expect(repo.createCalls, hasLength(1));
      final c = repo.createCalls.single;
      expect(c.sportId, 's1');
      expect(c.sportVariantId, 'v1');
      expect(c.title, 'Sunrise run');
      expect(c.locationName, 'Kite Beach');
      expect(c.startAt, DateTime(2030, 1, 15, 18));
      expect(c.rsvpPolicy, 'open');
      expect(c.capacity, 8);
      expect(created, 'new1');
    });
  }

  testWidgets('prefilled: Today 6:00 AM or tomorrow, first sport, Open', (
    tester,
  ) async {
    final repo = FakeMeetupRepository();
    await pumpMeetups(
      tester,
      SingleChildScrollView(
        child: MeetupComposerScreen(
          onCreated: (_) {},
          initialPlace: const ComposerPlacePick(name: 'Kite Beach'),
        ),
      ),
      repo,
    );
    tester.takeException();
    await tester.enterText(find.byType(EditableText).first, 'Sunrise run');
    await tester.pump();
    await tester.ensureVisible(find.byType(DabblerComposerSubmit));
    await tester.tap(find.byType(DabblerComposerSubmit));
    await settle(tester);
    final c = repo.createCalls.single;
    final now = DateTime.now();
    final todaySix = DateTime(now.year, now.month, now.day, 6);
    expect(
      c.startAt,
      todaySix.isAfter(now)
          ? todaySix
          : DateTime(now.year, now.month, now.day + 1, 6),
    );
    expect(c.sportId, 's1');
    expect(c.rsvpPolicy, 'open');
    expect(c.capacity, 8);
  });

  testWidgets('opens as a design-system bottom sheet', (tester) async {
    final repo = FakeMeetupRepository();
    await pumpMeetups(
      tester,
      Builder(
        builder: (context) => DabblerButton(
          label: 'open',
          onPressed: () => showMeetupComposerSheet(context),
        ),
      ),
      repo,
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    tester.takeException();
    expect(find.byType(DabblerSheet), findsOneWidget);
    expect(find.text('Create meet-up'), findsWidgets);
    expect(find.byType(MeetupComposerScreen), findsOneWidget);
  });

  for (final e in <(String, String)>[
    ('organiser_required', 'Only organisers can create meet-ups.'),
    ('title_invalid', 'The title must be 3 to 80 characters.'),
    ('invalid_time_range', 'The end time must be after the start time.'),
    ('invalid_capacity', 'The capacity must be at least 1.'),
    ('auth_required', 'Sign in to continue.'),
    ('free_meetups_only', 'This option is not available yet.'),
    ('visibility_not_supported', 'This option is not available yet.'),
    ('boom', 'Failed to create meet-up'),
  ]) {
    testWidgets('server error ${e.$1} is shown inline', (tester) async {
      final repo = FakeMeetupRepository()
        ..createFailure = Failure(code: e.$1, message: e.$1);
      await _open(tester, repo: repo);
      await _fill(tester);
      await tester.ensureVisible(find.byType(DabblerComposerSubmit));
      await tester.tap(find.byType(DabblerComposerSubmit));
      await settle(tester);
      expect(find.text(e.$2), findsOneWidget);
    });
  }

  group('create entry is organiser-only', () {
    for (final c in <(String, bool, String?, bool, bool)>[
      ('flag off', false, 'p1', true, false),
      ('no profile', true, null, true, false),
      ('non-organiser (server says no)', true, 'p1', false, false),
      ('organiser', true, 'p1', true, true),
    ]) {
      test(c.$1, () async {
        final repo = FakeMeetupRepository()..canCreateResult = c.$4;
        final container = makeContainer(repo, <Override>[
          meetupsEnabledProvider.overrideWithValue(c.$2),
          meetupActorProfileIdProvider.overrideWithValue(c.$3),
        ]);
        container.listen(canOfferCreateMeetupProvider, (_, __) {});
        if (c.$3 != null) {
          await container.read(canCreateMeetupProvider(c.$3!).future);
        }
        expect(container.read(canOfferCreateMeetupProvider), c.$5);
      });
    }
  });
}
