import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/my_conversations_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/dm_thread_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_message_action.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';

// KAN-557: the Message action on another user's profile. Fake repository
// only; no network.
typedef _Variant = ({String name, Locale locale, double scale});

const List<_Variant> _variants = [
  (name: 'ltr', locale: Locale('en'), scale: 1.0),
  (name: 'rtl', locale: Locale('ar'), scale: 1.0),
  (name: 'ltr-200', locale: Locale('en'), scale: 2.0),
  (name: 'rtl-200', locale: Locale('ar'), scale: 2.0),
];

const _viewer = 'viewer-1';
const _target = 'target-1';
const _profileKey = ValueKey<String>('profile');
const _threadKey = ValueKey<String>('thread');

/// Holds every startDm until [release]; delegates to the fake.
class _GatedDm implements DmRepository {
  _GatedDm(this.inner);
  final FakeMessagingRepository inner;
  final Completer<void> gate = Completer<void>();
  void release() => gate.complete();

  @override
  Future<Result<String, Failure>> startDm(String otherUserId) async {
    final r = inner.startDm(otherUserId);
    await gate.future;
    return r;
  }

  @override
  Future<Result<void, Failure>> setMuted(String id, bool muted) =>
      inner.setMuted(id, muted);
}

class _Nav {
  String? param;
}

Widget _app(
  _Variant v, {
  required DmRepository repo,
  required DabblerToastController toasts,
  bool messaging = true,
  bool direct = true,
  String? viewer = _viewer,
  String? target = _target,
  bool blocked = false,
  _Nav? nav,
  bool inRow = false,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => inRow
            ? Padding(
                key: _profileKey,
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ProfileActionButtons(
                    follow: DabblerButton(
                      key: _followKey,
                      label: 'Follow',
                      fullWidth: true,
                      onPressed: () {},
                    ),
                    message: ProfileMessageAction(targetAuthUserId: target),
                  ),
                ),
              )
            : Center(
                key: _profileKey,
                child: ProfileMessageAction(targetAuthUserId: target),
              ),
      ),
      GoRoute(
        path: dmThreadRoutePath,
        name: dmThreadRouteName,
        builder: (c, s) {
          nav?.param = s.pathParameters[dmThreadRouteParam];
          return const SizedBox(key: _threadKey);
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      dmRepositoryProvider.overrideWithValue(repo),
      profileMessageActionFlagsProvider.overrideWithValue((
        messaging: messaging,
        direct: direct,
      )),
      profileMessageViewerIdProvider.overrideWithValue(viewer),
      blockedUserIdsProvider.overrideWith(
        (ref) async => blocked ? {_target} : <String>{},
      ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: v.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(v.scale)),
        child: DabblerToastProvider(controller: toasts, child: child!),
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

const _followKey = ValueKey<String>('follow');

Finder get _button => find.byKey(ProfileMessageAction.buttonKey);

DabblerButton _btn(WidgetTester tester) =>
    tester.widget<DabblerButton>(_button);

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(_profileKey)));

void main() {
  for (final v in _variants) {
    group('[${v.name}]', () {
      late DabblerToastController toasts;
      setUp(() => toasts = DabblerToastController());
      tearDown(() => toasts.dispose());

      testWidgets('present when both flags on, signed in, not self', (
        tester,
      ) async {
        final repo = FakeMessagingRepository(currentUserId: _viewer);
        await tester.pumpWidget(_app(v, repo: repo, toasts: toasts));
        await _settle(tester);
        expect(_button, findsOneWidget);
        final b = _btn(tester);
        expect(b.disabled, isFalse);
        expect(b.semanticLabel, _l10n(tester).messaging_dm_action_semantic);
        // A labelled button, as in the design: the visible text is the label.
        expect(b.label, _l10n(tester).messaging_dm_action_label);
        expect(
          find.descendant(
            of: _button,
            matching: find.text(_l10n(tester).messaging_dm_action_label),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('Follow and Message lay out without overflow', (
        tester,
      ) async {
        final repo = FakeMessagingRepository(currentUserId: _viewer);
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _app(v, repo: repo, toasts: toasts, inRow: true),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        final l10n = _l10n(tester);
        expect(find.text(l10n.messaging_dm_action_label), findsOneWidget);
        expect(find.text('Follow'), findsOneWidget);
        final follow = tester.getRect(find.byKey(_followKey));
        final message = tester.getRect(_button);
        if (v.scale > ProfileActionButtons.stackAboveScale) {
          expect(message.top, greaterThanOrEqualTo(follow.bottom));
        } else {
          expect(message.top, follow.top);
          expect(message.width, closeTo(follow.width, 0.5));
          // Message follows Follow in reading order.
          final isRtl = v.locale.languageCode == 'ar';
          expect(
            isRtl ? message.right <= follow.left : message.left >= follow.right,
            isTrue,
          );
        }
      });

      for (final c in [
        (
          name: 'messaging flag off',
          m: false,
          d: true,
          viewer: _viewer,
          t: _target,
        ),
        (
          name: 'direct flag off',
          m: true,
          d: false,
          viewer: _viewer,
          t: _target,
        ),
        (name: 'signed out', m: true, d: true, viewer: null, t: _target),
        (name: 'self', m: true, d: true, viewer: _target, t: _target),
        (name: 'target not loaded', m: true, d: true, viewer: _viewer, t: null),
      ]) {
        testWidgets('hidden: ${c.name}', (tester) async {
          final repo = FakeMessagingRepository(currentUserId: _viewer);
          await tester.pumpWidget(
            _app(
              v,
              repo: repo,
              toasts: toasts,
              messaging: c.m,
              direct: c.d,
              viewer: c.viewer,
              target: c.t,
            ),
          );
          await _settle(tester);
          expect(_button, findsNothing);
        });
      }

      testWidgets('tap opens the thread with the returned id', (tester) async {
        final repo = FakeMessagingRepository(
          currentUserId: _viewer,
          idGenerator: () => 'abc',
        );
        final nav = _Nav();
        await tester.pumpWidget(_app(v, repo: repo, toasts: toasts, nav: nav));
        await _settle(tester);
        await tester.tap(_button);
        await _settle(tester);
        expect(repo.startDmCalls, 1);
        expect(nav.param, 'dm-abc');
        expect(find.byKey(_threadKey), findsOneWidget);
      });

      testWidgets('busy while pending; double tap calls startDm once', (
        tester,
      ) async {
        final fake = FakeMessagingRepository(
          currentUserId: _viewer,
          idGenerator: () => 'x',
        );
        final repo = _GatedDm(fake);
        final nav = _Nav();
        await tester.pumpWidget(_app(v, repo: repo, toasts: toasts, nav: nav));
        await _settle(tester);
        await tester.tap(_button);
        await tester.pump();
        expect(_btn(tester).loading, isTrue);
        await tester.tap(_button, warnIfMissed: false);
        await tester.pump();
        repo.release();
        await _settle(tester);
        expect(fake.startDmCalls, 1);
        expect(nav.param, 'dm-x');
      });

      for (final f
          in <
            ({
              String name,
              void Function(FakeMessagingRepository) arm,
              String Function(AppLocalizations) text,
            })
          >[
            (
              name: 'blocked',
              arm: (r) =>
                  r.failNextDm(FakeDmOp.startDm, MessagingReason.blocked),
              text: (l) => l.messaging_reason_blocked,
            ),
            (
              name: 'under_age',
              arm: (r) =>
                  r.failNextDm(FakeDmOp.startDm, MessagingReason.underAge),
              text: (l) => l.messaging_reason_under_age,
            ),
            (
              name: 'rate_limited',
              arm: (r) =>
                  r.failNextDm(FakeDmOp.startDm, MessagingReason.rateLimited),
              text: (l) => l.messaging_reason_rate_limited,
            ),
            (
              name: 'dm_cap_reached',
              arm: (r) => r.failNextDmCapReached(),
              text: (l) => l.messaging_reason_dm_cap_reached,
            ),
          ]) {
        testWidgets('failure ${f.name}: localized toast, stays on profile', (
          tester,
        ) async {
          final repo = FakeMessagingRepository(currentUserId: _viewer);
          f.arm(repo);
          final nav = _Nav();
          await tester.pumpWidget(
            _app(v, repo: repo, toasts: toasts, nav: nav),
          );
          await _settle(tester);
          await tester.tap(_button);
          await _settle(tester);
          final l10n = _l10n(tester);
          expect(toasts.visible.map((e) => e.spec.message), [f.text(l10n)]);
          expect(nav.param, isNull);
          expect(find.byKey(_profileKey), findsOneWidget);
          final b = _btn(tester);
          expect(b.loading, isFalse);
          expect(b.disabled, isFalse);
          for (final e in toasts.visible.toList()) {
            toasts.dismiss(e.id);
          }
          await tester.pump(const Duration(seconds: 10));
        });
      }

      testWidgets('blocked either direction: disabled with the reason', (
        tester,
      ) async {
        final repo = FakeMessagingRepository(currentUserId: _viewer);
        await tester.pumpWidget(
          _app(v, repo: repo, toasts: toasts, blocked: true),
        );
        await _settle(tester);
        final l10n = _l10n(tester);
        final b = _btn(tester);
        expect(b.disabled, isTrue);
        expect(b.semanticLabel, l10n.user_profile_cannot_message_blocked);
        expect(
          find.ancestor(of: _button, matching: find.byType(DabblerTooltip)),
          findsOneWidget,
        );
        await tester.tap(_button, warnIfMissed: false);
        await _settle(tester);
        expect(repo.startDmCalls, 0);
      });
    });
  }
}
