import 'dart:async';
import 'dart:math' as math;

import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_follow.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetups_screen.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import 'meetup_screens_harness.dart';

/// Listings fidelity (phase 6): the Meetups listing measured against
/// `Listings.dc.html` "Meetups listing" — card shell and spacing, LTR and
/// RTL, a 2x text scale, dark contrast of the card text, and the loading,
/// empty and error states.

class _Denied extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

Future<void> _pump(
  WidgetTester tester,
  FakeMeetupRepository repo, {
  Locale locale = const Locale('en'),
  bool dark = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meetupRepositoryProvider.overrideWithValue(repo),
        activePersonaProvider.overrideWithValue(PersonaType.player),
        activeLocationProvider.overrideWith(_Denied.new),
        myProfileIdProvider.overrideWith((ref) async => 'me'),
        isFollowingProvider.overrideWith((ref, p) async => false),
        meetupFollowActionProvider.overrideWithValue(
          ({
            required String myProfileId,
            required String targetProfileId,
            required bool currentlyFollowing,
          }) async {},
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: DabblerToastProvider(child: child!),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(
            dark ? ThemeData.dark() : ThemeData.light(),
          ),
          locale: locale,
        ),
        home: const MeetupsScreen(),
      ),
    ),
  );
  await settle(tester);
}

FakeMeetupRepository _rows() => FakeMeetupRepository()
  ..list = <MeetupListItem>[
    meetupRow('a', minSkill: 1, maxSkill: 2, going: 24),
    meetupRow(
      'b',
      title: 'Hatta trail hike',
      startsIn: const Duration(days: 3),
    ),
    meetupRow('c', title: 'يوغا الغروب', startsIn: const Duration(days: 4)),
  ];

double _contrast(Color a, Color b) {
  final double l1 = a.computeLuminance();
  final double l2 = b.computeLuminance();
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  setUpAll(loadRenderFonts);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('cards: white 18 shell, 15 under the tabs, 12 apart ($dir)', (
      tester,
    ) async {
      await _pump(tester, _rows(), locale: locale);
      expect(tester.takeException(), isNull);
      final List<Rect> r = <Rect>[
        for (final Element e in find.byType(DabblerCardGame).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ]..sort((a, b) => a.top.compareTo(b.top));
      expect(r.length, greaterThanOrEqualTo(2));
      final DabblerCard shell = tester.widget<DabblerCard>(
        find
            .descendant(
              of: find.byType(DabblerCardGame).first,
              matching: find.byType(DabblerCard),
            )
            .first,
      );
      expect(shell.variant, DabblerCardVariant.white);
      expect(shell.radius, DabblerRadius.xl);
      final double tabs = tester.getBottomLeft(find.byType(DabblerTabs)).dy;
      expect(r[0].top - tabs, ListingLayout.listTop);
      expect(r[1].top - r[0].bottom, ListingLayout.cardGap);
      expect(r[0].left, ListingLayout.gutter);
      expect(393 - r[0].right, ListingLayout.gutter);
      // Activity and skill on the frame's listing tags.
      expect(find.byType(DabblerListingTag), findsWidgets);
      expect(find.byType(DabblerBadge), findsNothing);
      // The price is the figure-XL step (`Listings.dc.html:553`).
      final AppLocalizations l = lookupAppLocalizations(locale);
      expect(
        tester.widget<Text>(find.text(l.listing_free).first).style!.fontSize,
        DabblerType.figureXl
            .resolveForDirection(
              dir == 'rtl' ? TextDirection.rtl : TextDirection.ltr,
            )
            .fontSize,
      );
    });

    testWidgets('upcoming: one going meetup is the ring-first tile ($dir)', (
      tester,
    ) async {
      final repo = _rows()
        ..list = <MeetupListItem>[
          meetupRow('m', my: 'going', startsIn: const Duration(hours: 19)),
          meetupRow('a'),
        ];
      await _pump(tester, repo, locale: locale);
      final DabblerCardUpcoming u = tester.widget<DabblerCardUpcoming>(
        find.byType(DabblerCardUpcoming),
      );
      expect(u.month, isNull);
      final AppLocalizations l = lookupAppLocalizations(locale);
      expect(
        tester.getTopLeft(find.byType(DabblerCardUpcoming)).dy -
            tester.getBottomLeft(find.text(l.listing_upcoming)).dy,
        ListingLayout.upcomingGap,
      );
    });

    testWidgets('2x text: no overflow ($dir)', (tester) async {
      await _pump(tester, _rows(), locale: locale, textScale: 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark: card text clears 4.5:1 ($dir)', (tester) async {
      await _pump(tester, _rows(), locale: locale, dark: true);
      expect(tester.takeException(), isNull);
      final Finder card = find.byType(DabblerCardGame).first;
      final DabblerColors c = DabblerColors.of(tester.element(card));
      for (final Text t in tester.widgetList<Text>(
        find.descendant(of: card, matching: find.byType(Text)),
      )) {
        final Color? ink = t.style?.color;
        if (ink == null || ink.a == 0) continue;
        if (ink == c.onBrand || ink == c.brandPrimary) continue;
        if (find
            .ancestor(
              of: find.byWidget(t),
              matching: find.byType(DabblerListingTag),
            )
            .evaluate()
            .isNotEmpty) {
          continue;
        }
        expect(
          _contrast(ink, c.surfaceCard),
          greaterThanOrEqualTo(4.5),
          reason: '"${t.data}"',
        );
      }
    });

    testWidgets('loading: three meetup skeletons ($dir)', (tester) async {
      final repo = _rows()..listGate = Completer<void>();
      await _pump(tester, repo, locale: locale);
      expect(
        tester
            .widgetList<DabblerListingSkeleton>(
              find.byType(DabblerListingSkeleton),
            )
            .where((s) => s.kind == DabblerListingSkeletonKind.meetup),
        hasLength(3),
      );
      repo.listGate!.complete();
      await settle(tester);
    });

    testWidgets('empty: the listing empty state, 60 under the chrome ($dir)', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeMeetupRepository()..list = const <MeetupListItem>[],
        locale: locale,
      );
      final DabblerEmptyState e = tester.widget<DabblerEmptyState>(
        find.byType(DabblerEmptyState),
      );
      expect(e.size, DabblerEmptyStateSize.listing);
      expect(e.icon, 'people');
      final double tabs = tester.getBottomLeft(find.byType(DabblerTabs)).dy;
      expect(
        tester.getTopLeft(find.byType(DabblerEmptyState)).dy - tabs,
        ListingLayout.emptyTop,
      );
    });

    testWidgets('error: the error state with a retry ($dir)', (tester) async {
      await _pump(tester, _rows()..listError = 'offline', locale: locale);
      final DabblerEmptyState e = tester.widget<DabblerEmptyState>(
        find.byType(DabblerEmptyState),
      );
      expect(e.tone, DabblerEmptyStateTone.error);
      expect(e.onRetry, isNotNull);
    });
  }
}
