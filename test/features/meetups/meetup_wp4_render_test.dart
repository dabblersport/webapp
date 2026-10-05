import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_follow.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_share.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_user_lookup.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_composer_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_edit_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_manage_screen.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import 'meetup_screens_harness.dart';

/// Renders the KAN-430 screens LTR and RTL. Writes PNGs only with
/// `--dart-define=MEETUPS_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('MEETUPS_SHOTS_DIR');

class _Ready extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    const ActiveLocation(
      lat: 25.2,
      lng: 55.27,
      source: ActiveLocationSource.saved,
      area: Area(
        id: 'a1',
        name: 'Dubai Marina',
        district: 'Marina',
        city: 'Dubai',
        country: 'AE',
        centerLat: 25.2,
        centerLng: 55.27,
      ),
    ),
  );
}

Future<void> _shoot(
  WidgetTester tester,
  Widget home,
  FakeMeetupRepository repo,
  Locale locale,
  String name, {
  Future<void> Function()? before,
  double height = 852,
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meetupRepositoryProvider.overrideWithValue(repo),
        activeLocationProvider.overrideWith(_Ready.new),
        myProfileIdProvider.overrideWith((ref) async => 'me'),
        isFollowingProvider.overrideWith((ref, p) async => false),
        meetupFollowActionProvider.overrideWithValue(
          ({
            required String myProfileId,
            required String targetProfileId,
            required bool currentlyFollowing,
          }) async {},
        ),
        meetupShareProvider.overrideWithValue((l, h) async {}),
        meetupUserIdLookupProvider.overrideWithValue((p) async => 'u-$p'),
      ],
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
        home: Builder(
          builder: (context) => ColoredBox(
            color: DabblerColors.of(context).bgPrimary,
            child: home,
          ),
        ),
      ),
    ),
  );
  await settle(tester);
  await before?.call();
  tester.takeException();
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

MeetupCard _card({bool host = false}) => MeetupCard(
  id: 'm1',
  title: 'Sunrise run',
  description: 'Easy pace along the shore',
  startAt: DateTime(2030, 1, 15, 18),
  endAt: DateTime(2030, 1, 15, 19),
  locationName: 'Kite Beach',
  capacity: 40,
  isHost: host,
  counts: const MeetupCounts(going: 24),
  sportNameEn: 'Running',
  host: const MeetupHost(actorProfileId: 'host1', displayName: 'Ahmed Farouk'),
  attendees: const <MeetupAvatar>[
    MeetupAvatar(displayName: 'Lina Haddad'),
    MeetupAvatar(displayName: 'Yousef Amer'),
  ],
);

const _going = MeetupAttendee(
  actorProfileId: 'p1',
  displayName: 'Lina Haddad',
  username: 'lina',
  status: RsvpStatus.going,
);
const _going2 = MeetupAttendee(
  actorProfileId: 'p4',
  displayName: 'Rami Kassab',
  username: 'rami',
  status: RsvpStatus.going,
);
const _interested = MeetupAttendee(
  actorProfileId: 'p2',
  displayName: 'Yousef Amer',
  username: 'yousef',
  status: RsvpStatus.interested,
);
const _pending = MeetupAttendee(
  actorProfileId: 'p3',
  displayName: 'Nadia Saleh',
  username: 'nadia',
  status: RsvpStatus.pending,
);

void main() {
  setUpAll(loadRenderFonts);

  for (final l in const <Locale>[Locale('en'), Locale('ar')]) {
    final t = l.languageCode;

    Future<void> create(
      WidgetTester tester,
      String name, {
      FakeMeetupRepository? repo,
      bool filled = false,
      bool advanced = false,
      bool submit = false,
    }) => _shoot(
      tester,
      Builder(
        builder: (context) => DabblerButton(
          label: 'open',
          onPressed: () => showMeetupComposerSheet(
            context,
            initialPlace: filled
                ? const ComposerPlacePick(name: 'Kite Beach')
                : null,
          ),
        ),
      ),
      repo ?? FakeMeetupRepository(),
      l,
      name,
      height: advanced ? 1250 : 852,
      before: () async {
        await tester.tap(find.text('open'));
        await settle(tester);
        tester.takeException();
        if (filled) {
          await tester.enterText(
            find.byType(EditableText).first,
            t == 'ar' ? 'جري الشروق' : 'Sunrise run',
          );
          await tester.pump();
        }
        if (advanced) {
          await tester.tap(
            find.text(t == 'ar' ? 'خيارات متقدمة' : 'Advanced options'),
          );
          await settle(tester);
        }
        if (submit) {
          await tester.tap(find.byType(DabblerButton).last);
          await settle(tester);
        }
      },
    );

    testWidgets('create default $t', (tester) async {
      await create(tester, 'meetups-create-default-$t');
    });

    testWidgets('create filled $t', (tester) async {
      await create(tester, 'meetups-create-filled-$t', filled: true);
    });

    testWidgets('create advanced $t', (tester) async {
      await create(
        tester,
        'meetups-create-advanced-$t',
        filled: true,
        advanced: true,
      );
    });

    testWidgets('create error $t', (tester) async {
      await create(
        tester,
        'meetups-create-error-$t',
        repo: FakeMeetupRepository()
          ..createFailure = const Failure(
            code: 'organiser_required',
            message: 'organiser_required',
          ),
        filled: true,
        submit: true,
      );
    });

    for (final s in <(String, List<MeetupAttendee>)>[
      ('going', [_going, _going2]),
      ('interested', [_interested]),
      ('pending', [_pending]),
    ]) {
      testWidgets('manage ${s.$1} $t', (tester) async {
        await _shoot(
          tester,
          MeetupManageScreen(meetupId: 'm1', onBack: () {}, onEdit: () {}),
          FakeMeetupRepository()..attendeeList = s.$2,
          l,
          'meetups-manage-${s.$1}-$t',
        );
      });
    }

    testWidgets('manage edit $t', (tester) async {
      await _shoot(
        tester,
        const MeetupEditScreen(meetupId: 'm1'),
        FakeMeetupRepository()..card = _card(host: true),
        l,
        'meetups-manage-edit-$t',
      );
    });

    testWidgets('manage cancel-confirm $t', (tester) async {
      await _shoot(
        tester,
        MeetupManageScreen(meetupId: 'm1', onBack: () {}, onEdit: () {}),
        FakeMeetupRepository()..attendeeList = [_going, _pending],
        l,
        'meetups-manage-cancel-confirm-$t',
        before: () async {
          await tester.drag(find.byType(ListView), const Offset(0, -600));
          await tester.pump();
          await tester.tap(
            find.text(t == 'ar' ? 'إلغاء اللقاء' : 'Cancel meetup'),
          );
          await settle(tester);
        },
      );
    });

    testWidgets('share header $t', (tester) async {
      await _shoot(
        tester,
        MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
        FakeMeetupRepository()
          ..card = _card()
          ..list = [meetupRow('m1', vibeKey: 'supportive')]
          ..eligibility = const RsvpEligibility(
            allowed: true,
            cta: RsvpCta.rsvpGoing,
          ),
        l,
        'meetups-share-header-$t',
      );
    });

    testWidgets('manage entry $t', (tester) async {
      await _shoot(
        tester,
        MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
        FakeMeetupRepository()
          ..card = _card(host: true)
          ..list = [meetupRow('m1', vibeKey: 'supportive')]
          ..eligibility = const RsvpEligibility(
            allowed: true,
            cta: RsvpCta.already,
          ),
        l,
        'meetups-manage-entry-$t',
      );
    });

    testWidgets('report menu $t', (tester) async {
      await _shoot(
        tester,
        MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
        FakeMeetupRepository()
          ..card = _card()
          ..eligibility = const RsvpEligibility(
            allowed: true,
            cta: RsvpCta.rsvpGoing,
          ),
        l,
        'meetups-report-menu-$t',
        before: () async {
          await tester.tap(
            find.bySemanticsLabel(t == 'ar' ? 'المزيد' : 'More'),
          );
          await settle(tester);
        },
      );
    });

    testWidgets('report dialog $t', (tester) async {
      await _shoot(
        tester,
        MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
        FakeMeetupRepository()
          ..card = _card()
          ..eligibility = const RsvpEligibility(
            allowed: true,
            cta: RsvpCta.rsvpGoing,
          ),
        l,
        'meetups-report-dialog-$t',
        before: () async {
          await tester.tap(
            find.bySemanticsLabel(t == 'ar' ? 'المزيد' : 'More'),
          );
          await settle(tester);
          await tester.tap(
            find.text(t == 'ar' ? 'الإبلاغ عن اللقاء' : 'Report meetup'),
          );
          await settle(tester);
          await settle(tester);
        },
      );
    });
  }
}
