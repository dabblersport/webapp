// KAN-557: the Message action on another user's profile. FAKES ONLY: a fake
// messaging repository, fake flags, a fake signed-in user and a fake block
// state. Nothing real is called. Each scenario runs in LTR and RTL and at 200
// percent text scale.
import 'dart:async';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/dm_thread_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_message_action_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show currentUserProvider;
import 'package:dabbler/features/profile/presentation/widgets/profile/profile_message_action.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';

typedef _Variant = ({String name, Locale locale, double scale});

const List<_Variant> _variants = [
  (name: 'ltr', locale: Locale('en'), scale: 1.0),
  (name: 'rtl', locale: Locale('ar'), scale: 1.0),
  (name: 'ltr-200', locale: Locale('en'), scale: 2.0),
  (name: 'rtl-200', locale: Locale('ar'), scale: 2.0),
];

const _me = 'user-me';
const _other = 'user-other';

UserProfile _user(String id) => UserProfile(
  id: id,
  userId: id,
  displayName: 'Fake $id',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// A fake repository whose startDm waits on [gate] (the busy state).
class _GatedDm extends FakeMessagingRepository {
  Completer<Result<String, Failure>>? gate;

  @override
  Future<Result<String, Failure>> startDm(String otherUserId) {
    final g = gate;
    if (g == null) return super.startDm(otherUserId);
    startDmCalls++;
    return g.future;
  }
}

class _Nav {
  final opened = <String>[];
}

Widget _app(
  FakeMessagingRepository repo,
  _Variant v,
  _Nav nav, {
  bool messaging = true,
  bool direct = true,
  UserProfile? viewer,
  String? target = _other,
  bool blocked = false,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [ProfileMessageAction(targetUserId: target)],
            ),
          ),
        ),
      ),
      GoRoute(
        path: dmThreadRoutePath,
        name: dmThreadRouteName,
        builder: (c, s) {
          nav.opened.add(s.pathParameters[dmThreadRouteParam]!);
          return const SizedBox(key: ValueKey('thread'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      dmRepositoryProvider.overrideWithValue(repo),
      profileMessageFlagsProvider.overrideWithValue((
        messaging: messaging,
        direct: direct,
      )),
      currentUserProvider.overrideWithValue(viewer),
      isUserBlockedProvider.overrideWith((ref, id) async => blocked),
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
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _action = find.byKey(ProfileMessageAction.buttonKey);

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  test('the new flag defaults to false in committed code', () {
    expect(FeatureFlags.enableMessagingDirect, isFalse);
    expect(FeatureFlags.getFeatureFlag('messaging_direct'), isFalse);
    expect(
      FeatureFlags.getEnabledFeatures(),
      isNot(contains('messaging_direct')),
    );
  });

  for (final v in _variants) {
    final l10n = lookupAppLocalizations(v.locale);

    group('[${v.name}]', () {
      testWidgets('shown only when both flags are on, signed in and not self', (
        tester,
      ) async {
        final nav = _Nav();
        Future<void> pump({
          bool messaging = true,
          bool direct = true,
          UserProfile? viewer,
          String? target = _other,
        }) async {
          await tester.pumpWidget(
            _app(
              FakeMessagingRepository(),
              v,
              nav,
              messaging: messaging,
              direct: direct,
              viewer: viewer,
              target: target,
            ),
          );
          await _settle(tester);
        }

        await pump(viewer: _user(_me));
        expect(_action, findsOneWidget);
        expect(tester.takeException(), isNull);

        await pump(viewer: _user(_me), messaging: false); // master flag off
        expect(_action, findsNothing);
        await pump(viewer: _user(_me), direct: false); // sub-flag off
        expect(_action, findsNothing);
        await pump(viewer: null); // signed out
        expect(_action, findsNothing);
        await pump(viewer: _user(_other)); // own profile
        expect(_action, findsNothing);
        await pump(viewer: _user(_me), target: null); // profile not loaded
        expect(_action, findsNothing);
      });

      testWidgets(
        'tap success: busy state, the thread opens with the returned id',
        (tester) async {
          final repo = _GatedDm()..gate = Completer<Result<String, Failure>>();
          final nav = _Nav();
          await tester.pumpWidget(_app(repo, v, nav, viewer: _user(_me)));
          await _settle(tester);
          expect(
            find.bySemanticsLabel(l10n.messaging_dm_action_label),
            findsOneWidget,
          );

          await tester.tap(_action);
          await tester.pump();
          await tester.pump();
          expect(repo.startDmCalls, 1);
          // Busy: announced as opening, and the loading state is drawn.
          expect(
            find.bySemanticsLabel(l10n.messaging_dm_action_opening),
            findsOneWidget,
          );
          expect(nav.opened, isEmpty);

          repo.gate!.complete(const Ok('dm-1'));
          await _settle(tester);
          expect(nav.opened, ['dm-1']);
          expect(find.byKey(const ValueKey('thread')), findsOneWidget);
        },
      );

      testWidgets('repeat taps while busy are ignored: only one DM opens', (
        tester,
      ) async {
        final repo = _GatedDm()..gate = Completer<Result<String, Failure>>();
        final nav = _Nav();
        await tester.pumpWidget(_app(repo, v, nav, viewer: _user(_me)));
        await _settle(tester);
        await tester.tap(_action);
        await tester.pump();
        await tester.tap(_action, warnIfMissed: false);
        await tester.pump();
        await tester.tap(_action, warnIfMissed: false);
        await tester.pump();
        expect(repo.startDmCalls, 1);
        repo.gate!.complete(const Ok('dm-1'));
        await _settle(tester);
        expect(nav.opened, ['dm-1']);
      });

      testWidgets('an existing pair reopens the same thread', (tester) async {
        final repo = FakeMessagingRepository();
        final nav = _Nav();
        await tester.pumpWidget(_app(repo, v, nav, viewer: _user(_me)));
        await _settle(tester);
        await tester.tap(_action);
        await _settle(tester);
        expect(nav.opened, hasLength(1));
      });

      for (final c
          in <
            (
              String,
              void Function(FakeMessagingRepository),
              String Function(AppLocalizations),
            )
          >[
            (
              'blocked',
              (r) => r.failNextDm(FakeDmOp.startDm, MessagingReason.blocked),
              (l) => l.messaging_dm_action_blocked,
            ),
            (
              'under_age (not_in_pilot)',
              (r) => r.failNextDm(FakeDmOp.startDm, MessagingReason.notInPilot),
              (l) => l.messaging_dm_action_under_age,
            ),
            (
              'rate_limited',
              (r) =>
                  r.failNextDm(FakeDmOp.startDm, MessagingReason.rateLimited),
              (l) => l.messaging_dm_action_rate_limited,
            ),
            (
              'dm_cap_reached',
              (r) => r.failNextDmCapReached(),
              (l) => l.messaging_dm_action_cap_reached,
            ),
            (
              'not_found',
              (r) => r.failNextDm(FakeDmOp.startDm, MessagingReason.notFound),
              (l) => l.messaging_dm_action_failed,
            ),
            (
              'unknown',
              (r) => r.failNextDm(FakeDmOp.startDm, MessagingReason.unknown),
              (l) => l.messaging_dm_action_failed,
            ),
          ]) {
        testWidgets('a ${c.$1} failure shows its localized message and stays', (
          tester,
        ) async {
          final repo = FakeMessagingRepository();
          c.$2(repo);
          final nav = _Nav();
          await tester.pumpWidget(_app(repo, v, nav, viewer: _user(_me)));
          await _settle(tester);
          await tester.tap(_action);
          await _settle(tester);
          expect(find.text(c.$3(l10n)), findsOneWidget);
          expect(nav.opened, isEmpty);
          expect(_action, findsOneWidget); // still on the profile, idle again
          // The next tap works (the busy state cleared).
          await tester.tap(_action);
          await _settle(tester);
          expect(nav.opened, hasLength(1));
        });
      }

      testWidgets(
        'a block (either direction) disables the action with the reason',
        (tester) async {
          final repo = FakeMessagingRepository();
          final nav = _Nav();
          await tester.pumpWidget(
            _app(repo, v, nav, viewer: _user(_me), blocked: true),
          );
          await _settle(tester);
          expect(_action, findsOneWidget);
          expect(
            find.bySemanticsLabel(l10n.messaging_dm_action_blocked),
            findsOneWidget,
          );
          await tester.tap(_action, warnIfMissed: false);
          await _settle(tester);
          expect(repo.startDmCalls, 0);
          expect(nav.opened, isEmpty);
        },
      );
    });
  }
}
