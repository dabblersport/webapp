import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/presentation/dm_thread_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
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
// overrides only; the committed flags are never flipped.

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

final List<MyConversation> _rows = [
  const MyConversation(
    conversationId: 'conv-m1',
    kind: MyConversationKind.meetup,
    meetupId: 'm1',
    state: MyConversationState.send,
  ),
  const MyConversation(
    conversationId: 'conv-other',
    kind: MyConversationKind.meetup,
    meetupId: 'm2',
    state: MyConversationState.send,
  ),
];

class _Nav {
  String? param;
}

Future<_Nav> _pump(
  WidgetTester tester, {
  required MeetupCard card,
  MeetupChatEntryFlags flags = _allOn,
  Future<Result<List<MyConversation>, Failure>> Function()? list,
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
        path: dmThreadRoutePath,
        name: dmThreadRouteName,
        builder: (c, s) {
          nav.param = s.pathParameters[dmThreadRouteParam];
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
        messagesListProvider.overrideWith(
          (ref) => (list ?? () async => Ok(_rows))(),
        ),
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
      testWidgets('organiser sees the entry; tap opens the resolved chat', (
        tester,
      ) async {
        final nav = await _pump(tester, card: _card(host: true), v: v);
        expect(_entry, findsOneWidget);
        expect(tester.takeException(), isNull);
        await _tapEntry(tester);
        expect(nav.param, 'conv-m1');
        expect(find.byKey(const ValueKey('thread')), findsOneWidget);
      });

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
        expect(nav.param, 'conv-m1');
      });

      testWidgets('no conversation row yet: visible, disabled, opens nothing', (
        tester,
      ) async {
        final nav = await _pump(
          tester,
          card: _card(my: 'going'),
          list: () async => Ok(<MyConversation>[_rows.last]),
          v: v,
        );
        expect(_entry, findsOneWidget);
        final b = _button(tester);
        expect(b.disabled, isTrue);
        expect(b.loading, isFalse);
        final l = AppLocalizations.of(tester.element(_entry));
        expect(b.semanticLabel, l.messaging_meetup_chat_unavailable);
        await _tapEntry(tester);
        expect(nav.param, isNull);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('list failure: visible, disabled, opens nothing', (tester) async {
    final nav = await _pump(
      tester,
      card: _card(host: true),
      list: () async => Err(Failure(message: 'x')),
    );
    expect(_button(tester).disabled, isTrue);
    await _tapEntry(tester);
    expect(nav.param, isNull);
  });

  testWidgets('while resolving: loading and disabled', (tester) async {
    final gate = Completer<Result<List<MyConversation>, Failure>>();
    await _pump(tester, card: _card(host: true), list: () => gate.future);
    final b = _button(tester);
    expect(b.loading, isTrue);
    expect(b.disabled, isTrue);
    gate.complete(Ok(_rows));
    await settle(tester);
    expect(_button(tester).disabled, isFalse);
  });

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
