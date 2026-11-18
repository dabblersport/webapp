// KAN-1003: fakes and a router host for the security screens.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/security/data/security_repository.dart';
import 'package:dabbler/features/security/domain/security_sign_in.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const List<Locale> kLocales = <Locale>[Locale('en'), Locale('ar')];

SecuritySignIn signIn(
  String id, {
  String device = 'iPhone 15',
  SignInState state = SignInState.newDevice,
  bool current = false,
  bool active = true,
  String? city,
  DateTime? at,
}) => SecuritySignIn(
  id: id,
  deviceLabel: device,
  signedInAt: at ?? DateTime(2026, 11, 18, 9, 12),
  state: state,
  city: city,
  isCurrent: current,
  isActive: active,
);

class FakeSecurityRepo implements SecurityRepository {
  FakeSecurityRepo(this.rows);

  List<SecuritySignIn> rows;
  Failure? loadFail;
  Failure? answerFail;
  Completer<void>? gate;
  final List<String> calls = <String>[];

  @override
  Future<Result<List<SecuritySignIn>, Failure>> signIns() async {
    calls.add('load');
    final f = loadFail;
    return f == null ? Ok(rows) : Err(f);
  }

  Future<Result<void, Failure>> _answer(String what) async {
    calls.add(what);
    if (gate != null) await gate!.future;
    final f = answerFail;
    return f == null ? const Ok(null) : Err(f);
  }

  @override
  Future<Result<void, Failure>> confirm(String id) => _answer('confirm:$id');

  @override
  Future<Result<void, Failure>> notMe(String id) => _answer('notMe:$id');
}

/// Pumps [home] at `/` under a router; `/settings/account` and
/// `/security/sign-ins` are markers whose key carries the location.
Future<void> pumpSecurity(
  WidgetTester tester,
  FakeSecurityRepo repo,
  Widget home, {
  Locale locale = const Locale('en'),
  bool use24h = false,
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  Widget marker(GoRouterState s) =>
      SizedBox(key: ValueKey<String>('at:${s.uri}'));
  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(path: '/settings/account', builder: (_, s) => marker(s)),
      GoRoute(path: '/security/sign-ins', builder: (_, s) => marker(s)),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        securityRepositoryProvider.overrideWithValue(repo),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
          child: DabblerToastProvider(child: child!),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(ValueKey<String>(k));

Finder text(String s) => find.textContaining(s, findRichText: true);
