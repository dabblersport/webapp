import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:dabbler/features/messaging/presentation/meetup_chat_route.dart';
import 'package:dabbler/features/messaging/presentation/widgets/meetup_chat_entry.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';
import 'meetup_screens_harness.dart';

// KAN-559: the meetup-chat entry on the meetup detail screen. Provider
// overrides only; the committed flags are never flipped. KAN-928: it opens
// /meetups/{id}/chat directly (the Worker creates the conversation).

typedef _Variant = ({String name, Locale locale, double scale});

const List<_Variant> _variants = [
  (name: 'ltr', locale: Locale('en'), scale: 1.0),
  (name: 'rtl', locale: Locale('ar'), scale: 1.0),
  (name: 'ltr-200', locale: Locale('en'), scale: 2.0),
  (name: 'rtl-200', locale: Locale('ar'), scale: 2.0),
];

const MeetupChatEntryFlags _allOn = (
  messaging: true,
  gameChat: true,
  reporting: true,
  meetups: true,
);

class _Denied extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

MeetupCard _card({bool host = false, String? my}) => MeetupCard(
  id: 'm1',
  title: 'Sunrise run',
  startAt: DateTime.now().add(const Duration(days: 1)),
  counts: const MeetupCounts(going: 3),
  isHost: host,
  myStatus: my,
);

class _Nav {
  String? param;
  Object? extra;
}

Future<_Nav> _pump(
  WidgetTester tester, {
  required MeetupCard card,
  MeetupChatEntryFlags flags = _allOn,
  _Variant v = const (name: 'ltr', locale: Locale('en'), scale: 1.0),
}) async {
  final nav = _Nav();
  final repo = FakeMeetupRepository()
    ..card = card
    ..eligibility = const RsvpEligibility(
      allowed: true,
      cta: RsvpCta.rsvpGoing,
    );
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
      ),
      GoRoute(
        path: meetupChatRoutePath,
        builder: (c, s) {
          nav.param = s.pathParameters['meetupId'];
          nav.extra = s.extra;
          return const SizedBox(key: ValueKey('thread'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meetupRepositoryProvider.overrideWithValue(repo),
        activePersonaProvider.overrideWithValue(PersonaType.player),
        activeLocationProvider.overrideWith(_Denied.new),
        myProfileIdProvider.overrideWith((ref) async => 'me'),
        isFollowingProvider.overrideWith((ref, p) async => false),
        meetupChatEntryFlagsProvider.overrideWithValue(flags),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        locale: v.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: v.locale,
        ),
        builder: (context, child) => DabblerToastProvider(
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(v.scale)),
            child: child!,
          ),
        ),
        routerConfig: router,
      ),
    ),
  );
  await settle(tester);
  return nav;
}

final _entry = find.byKey(MeetupChatEntry.buttonKey, skipOffstage: false);

DabblerButton _button(WidgetTester t) => t.widget<DabblerButton>(_entry);

Future<void> _tapEntry(WidgetTester tester) async {
  await tester.ensureVisible(_entry);
  await tester.pump();
  await tester.tap(_entry);
  await settle(tester);
}

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  for (final v in _variants) {
    group('[${v.name}]', () {
      testWidgets(
        'organiser sees the entry; tap opens the meetup chat with its title',
        (tester) async {
          final nav = await _pump(tester, card: _card(host: true), v: v);
          expect(_entry, findsOneWidget);
          expect(tester.takeException(), isNull);
          await _tapEntry(tester);
          expect(nav.param, 'm1');
          expect(nav.extra, 'Sunrise run');
          expect(find.byKey(const ValueKey('thread')), findsOneWidget);
        },
      );

      testWidgets('a going member sees the entry; tap opens the chat', (
        tester,
      ) async {
        final nav = await _pump(
          tester,
          card: _card(my: 'going'),
          v: v,
        );
        expect(_entry, findsOneWidget);
        await _tapEntry(tester);
        expect(nav.param, 'm1');
      });

      testWidgets('enabled at once: no conversation id to resolve', (
        tester,
      ) async {
        await _pump(
          tester,
          card: _card(my: 'going'),
          v: v,
        );
        final b = _button(tester);
        expect(b.disabled, isFalse);
        expect(b.loading, isFalse);
        final l = AppLocalizations.of(tester.element(_entry));
        expect(b.semanticLabel, l.messaging_meetup_chat_semantic);
        expect(tester.takeException(), isNull);
      });
    });
  }

  for (final my in <String?>[null, 'interested', 'declined', 'cancelled']) {
    testWidgets('absent for a non-member (my status $my)', (tester) async {
      await _pump(tester, card: _card(my: my));
      expect(_entry, findsNothing);
    });
  }

  final offCases = <String, MeetupChatEntryFlags>{
    'messaging off': (
      messaging: false,
      gameChat: true,
      reporting: true,
      meetups: true,
    ),
    'game chat off': (
      messaging: true,
      gameChat: false,
      reporting: true,
      meetups: true,
    ),
    'reporting off': (
      messaging: true,
      gameChat: true,
      reporting: false,
      meetups: true,
    ),
    'meetups off': (
      messaging: true,
      gameChat: true,
      reporting: true,
      meetups: false,
    ),
  };
  offCases.forEach((name, flags) {
    testWidgets('absent for the organiser when $name', (tester) async {
      await _pump(tester, card: _card(host: true), flags: flags);
      expect(_entry, findsNothing);
    });
  });
}
