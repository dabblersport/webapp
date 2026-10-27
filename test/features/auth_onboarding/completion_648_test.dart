import 'dart:async';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/auth_onboarding/data/onboarding_intention_store.dart';
import 'package:dabbler/features/auth_onboarding/data/repositories/onboarding_repository.dart';
import 'package:dabbler/features/auth_onboarding/data/unified_onboarding_client.dart';
import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_intention.dart';
import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_state.dart';
import 'package:dabbler/features/auth_onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/profile/onboarding_welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/intent_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/services/onboarding_completion_path.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render_mode.dart';

const _uuid = '11111111-2222-3333-4444-555555555555';

class _NoRepo implements OnboardingRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _FakeAuth extends StateNotifier<SimpleAuthState>
    implements SimpleAuthNotifier {
  _FakeAuth() : super(const SimpleAuthState(isAuthenticated: true));
  int refreshed = 0;

  @override
  Future<void> refreshAuthState() async => refreshed++;

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _FakeLocation extends StateNotifier<AsyncValue<LocationState>>
    implements SelectedLocationNotifier {
  _FakeLocation() : super(const AsyncValue.loading());

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Gateway implements OnboardingCompletionGateway {
  _Gateway({this.results = const []});

  /// Consumed one per unified call; an empty list means "succeed with _uuid".
  List<Result<String, UnifiedOnboardingFailure>> results;
  Object? avatarError;
  final calls = <String>[];
  final inputs = <UnifiedOnboardingInput>[];
  Future<void>? hold;

  @override
  Future<void> syncAuthMetadata({
    required String displayName,
    required String username,
  }) async => calls.add('meta');

  @override
  Future<Result<String, UnifiedOnboardingFailure>> onboardUnified(
    UnifiedOnboardingInput input,
  ) async {
    calls.add('unified');
    inputs.add(input);
    if (hold != null) await hold;
    if (results.isEmpty) return const Ok(_uuid);
    return results.removeAt(0);
  }

  @override
  Future<void> ensureAvatar(String profileId) async {
    calls.add('avatar:$profileId');
    final e = avatarError;
    if (e != null) {
      avatarError = null;
      throw e;
    }
  }

  @override
  Future<void> createLegacy({
    required RegistrationOnboardingData data,
    String? country,
    String? city,
  }) async => calls.add('legacy:${data.intention}');
}

RegistrationOnboardingData _data(
  OnboardingIntention? intention, {
  List<String>? interests = const ['s2', 's3'],
  String? primary = 's1',
}) => RegistrationOnboardingData(
  email: 'a@b.co',
  displayName: 'Sam',
  username: 'sam',
  age: 30,
  gender: 'male',
  intention: intention == OnboardingIntention.hostGames ? 'host' : 'player',
  onboardingIntention: intention,
  preferredSport: primary,
  interests: interests,
);

Widget _app(ProviderContainer c, GoRouter router, Locale locale) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        builder: (context, child) => DabblerToastProvider(child: child!),
        routerConfig: router,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('completion path and input', () {
    test('new account with an intention takes the unified path', () {
      for (final i in OnboardingIntention.values) {
        expect(
          onboardingCompletionPath(_data(i), resumingLegacyProfile: false),
          OnboardingCompletionPath.unified,
        );
      }
    });

    test('an existing legacy profile resuming keeps the legacy path', () {
      for (final i in OnboardingIntention.values) {
        expect(
          onboardingCompletionPath(_data(i), resumingLegacyProfile: true),
          OnboardingCompletionPath.legacyContinuation,
        );
      }
    });

    test('no recorded intention never guesses: legacy path', () {
      expect(
        onboardingCompletionPath(_data(null), resumingLegacyProfile: false),
        OnboardingCompletionPath.legacyContinuation,
      );
    });

    test('Primary is in Following, once, and nothing else is dropped', () {
      expect(interestsWithPrimary(_data(OnboardingIntention.organise)), [
        's1',
        's2',
        's3',
      ]);
      expect(
        interestsWithPrimary(
          _data(OnboardingIntention.organise, interests: ['s2', 's1']),
        ),
        ['s2', 's1'],
      );
      expect(
        interestsWithPrimary(
          _data(OnboardingIntention.organise, interests: null),
        ),
        ['s1'],
      );
    });

    test('the first three intentions give identical input but the key', () {
      UnifiedOnboardingInput build(OnboardingIntention i) => unifiedInputFor(
        _data(i),
        country: 'United Arab Emirates',
        city: 'Dubai',
      )!;
      final base = build(OnboardingIntention.connectPlay);
      for (final i in [
        OnboardingIntention.playOrganise,
        OnboardingIntention.organise,
      ]) {
        final other = build(i);
        expect(other.displayName, base.displayName);
        expect(other.username, base.username);
        expect(other.age, base.age);
        expect(other.gender, base.gender);
        expect(other.preferredSport, base.preferredSport);
        expect(other.interests, base.interests);
        expect(other.country, base.country);
        expect(other.city, base.city);
        expect(other.intention.targetPersona, base.intention.targetPersona);
        expect(other.intention, isNot(base.intention));
      }
      expect(base.intention.targetPersona, 'contributor');
      expect(
        build(OnboardingIntention.hostGames).intention.targetPersona,
        'partner',
      );
    });

    test('legacy persona: first three are the same, host_games is Host', () {
      expect(
        OnboardingIntention.values.map(
          (i) => i == OnboardingIntention.hostGames ? 'host' : 'player',
        ),
        ['player', 'player', 'player', 'host'],
      );
    });
  });

  group('intent screen', () {
    late ProviderContainer container;
    late GoRouter router;

    Future<void> pumpIntent(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(onboardingDataProvider.notifier).initWithEmail('a@b.co');
      router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const IntentSelectionScreen()),
          GoRoute(
            path: RoutePaths.interestsSelection,
            builder: (_, _) => const Text('interests-step'),
          ),
        ],
      );
      await tester.pumpWidget(_app(container, router, locale));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    testWidgets('offers the four intentions, bound to the KAN-650 copy', (
      tester,
    ) async {
      await pumpIntent(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(IntentSelectionScreen)),
      );
      expect(find.byType(DabblerSelectableCard), findsNWidgets(4));
      expect(find.text(l10n.onb_intention_title), findsOneWidget);
      for (final i in OnboardingIntention.values) {
        expect(find.text(i.label(l10n)), findsOneWidget);
      }
    });

    for (final i in OnboardingIntention.values) {
      testWidgets('choosing ${i.key} stores the key and the legacy persona', (
        tester,
      ) async {
        await pumpIntent(tester);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(IntentSelectionScreen)),
        );
        await tester.tap(find.text(i.label(l10n)));
        await tester.pump();
        await tester.tap(find.text(l10n.onb_continue));
        await tester.pumpAndSettle();
        final data = container.read(onboardingDataProvider)!;
        expect(data.onboardingIntention, i);
        expect(
          data.intention,
          i == OnboardingIntention.hostGames ? 'host' : 'player',
        );
        expect(find.text('interests-step'), findsOneWidget);
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        expect(await const OnboardingIntentionStore().load(), i);
      });
    }

    testWidgets('Continue is disabled until a choice is made', (tester) async {
      await pumpIntent(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(IntentSelectionScreen)),
      );
      await tester.tap(find.text(l10n.onb_continue), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('interests-step'), findsNothing);
    });

    testWidgets('an interrupted choice is restored and preselected', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        OnboardingIntentionStore.prefsKey: 'host_games',
      });
      await pumpIntent(tester);
      final cards = tester
          .widgetList<DabblerSelectableCard>(find.byType(DabblerSelectableCard))
          .toList();
      expect(cards.map((c) => c.selected), [false, false, false, true]);
    });

    testWidgets('renders in Arabic (RTL) with no English placeholder', (
      tester,
    ) async {
      await pumpIntent(tester, locale: const Locale('ar'));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(IntentSelectionScreen)),
      );
      expect(find.byType(DabblerSelectableCard), findsNWidgets(4));
      expect(find.text(l10n.onb_intention_title), findsOneWidget);
      expect(l10n.onb_intention_title, isNot('What brings you to Dabbler?'));
      expect(
        Directionality.of(
          tester.element(find.byType(DabblerSelectableCard).first),
        ),
        TextDirection.rtl,
      );
    });
  });

  group('welcome screen completion', () {
    late _Gateway gateway;
    late ProviderContainer container;
    late _FakeAuth auth;
    Object? welcomeExtra;
    var wentHome = false;
    var wentLanding = false;

    Future<void> pumpWelcome(
      WidgetTester tester, {
      RegistrationOnboardingData? data,
      bool legacyResume = false,
      bool signedIn = true,
    }) async {
      welcomeExtra = null;
      wentHome = false;
      wentLanding = false;
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      auth = _FakeAuth();
      container = ProviderContainer(
        overrides: [
          onboardingCompletionGatewayProvider.overrideWithValue(gateway),
          simpleAuthProvider.overrideWith((ref) => auth),
          sportsForSelectedCountryProvider.overrideWith(
            (ref) async => const <Sport>[],
          ),
          onboardingControllerProvider.overrideWith(
            (ref) => OnboardingController(repository: _NoRepo())
              ..state = OnboardingState(hasIncompleteOnboarding: legacyResume),
          ),
          selectedLocationProvider.overrideWith((ref) => _FakeLocation()),
          isAuthenticatedProvider.overrideWithValue(signedIn),
        ],
      );
      addTearDown(container.dispose);
      if (data != null) {
        container
            .read(onboardingDataProvider.notifier)
            .loadFromMap(data.toMap());
      }
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const ProfileOnboardingWelcomeScreen(),
          ),
          GoRoute(
            path: RoutePaths.welcome,
            builder: (ctx, state) {
              welcomeExtra = state.extra;
              return const Text('welcome');
            },
          ),
          GoRoute(
            path: RoutePaths.home,
            builder: (_, _) {
              wentHome = true;
              return const Text('home');
            },
          ),
          GoRoute(
            path: RoutePaths.landing,
            builder: (_, _) {
              wentLanding = true;
              return const Text('landing');
            },
          ),
        ],
      );
      await tester.pumpWidget(_app(container, router, const Locale('en')));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('all four choices call the unified RPC, then the avatar', (
      tester,
    ) async {
      for (final i in OnboardingIntention.values) {
        gateway = _Gateway();
        await pumpWelcome(tester, data: _data(i));
        expect(gateway.calls, [
          'meta',
          'unified',
          'avatar:$_uuid',
        ], reason: i.key);
        expect(gateway.inputs.single.intention, i);
        expect(gateway.inputs.single.interests, [
          's1',
          's2',
          's3',
        ], reason: 'Primary is in Following');
        expect(auth.refreshed, 1);
        expect(container.read(onboardingDataProvider), isNull);
        final extra = welcomeExtra as Map;
        expect(
          extra['personaType'],
          i == OnboardingIntention.hostGames ? 'host' : 'player',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('no optimistic completion: a failure never leaves the screen', (
      tester,
    ) async {
      gateway = _Gateway(
        results: [
          const Err(
            UnifiedOnboardingFailure(
              UnifiedOnboardingError.contributorSportsIncomplete,
            ),
          ),
        ],
      );
      await pumpWelcome(tester, data: _data(OnboardingIntention.organise));
      expect(welcomeExtra, isNull);
      expect(auth.refreshed, 0);
      expect(container.read(onboardingDataProvider), isNotNull);
      expect(
        find.text('Choose at least one sport to continue.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a retry reuses the persisted intention and input', (
      tester,
    ) async {
      gateway = _Gateway(
        results: [
          const Err(UnifiedOnboardingFailure(UnifiedOnboardingError.unknown)),
        ],
      );
      await pumpWelcome(tester, data: _data(OnboardingIntention.hostGames));
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(gateway.inputs, hasLength(2));
      expect(gateway.inputs[1].intention, OnboardingIntention.hostGames);
      expect(gateway.inputs[1].username, gateway.inputs[0].username);
      expect(gateway.inputs[1].interests, gateway.inputs[0].interests);
      expect(welcomeExtra, isNotNull);
    });

    testWidgets('an avatar failure retries with the same id, not a new RPC', (
      tester,
    ) async {
      gateway = _Gateway()..avatarError = Exception('storage down');
      await pumpWelcome(tester, data: _data(OnboardingIntention.connectPlay));
      expect(welcomeExtra, isNull);
      await tester.tap(find.text('Retry'));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(gateway.calls.where((c) => c == 'unified'), hasLength(1));
      expect(gateway.calls.where((c) => c == 'avatar:$_uuid'), hasLength(2));
      expect(welcomeExtra, isNotNull);
    });

    testWidgets('duplicate submit is ignored while the call is pending', (
      tester,
    ) async {
      final release = Completer();
      gateway = _Gateway()..hold = release.future;
      await pumpWelcome(tester, data: _data(OnboardingIntention.organise));
      final state =
          tester.state(find.byType(ProfileOnboardingWelcomeScreen)) as dynamic;
      // The first run (from initState) is still in flight.
      unawaited(state.submit() as Future<void>);
      unawaited(state.submit() as Future<void>);
      expect(gateway.inputs, hasLength(1));
      release.complete();
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(gateway.inputs, hasLength(1));
    });

    testWidgets('a dependency failure shows the generic localized error', (
      tester,
    ) async {
      gateway = _Gateway(
        results: [
          Err(
            UnifiedOnboardingFailure(
              UnifiedOnboardingError.unknown,
              cause: Exception('SocketException: connection reset'),
            ),
          ),
        ],
      );
      await pumpWelcome(tester, data: _data(OnboardingIntention.organise));
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('SocketException'), findsNothing);
    });

    testWidgets('an existing legacy user resumes on the legacy path', (
      tester,
    ) async {
      gateway = _Gateway();
      await pumpWelcome(
        tester,
        data: _data(OnboardingIntention.organise),
        legacyResume: true,
      );
      expect(gateway.calls, ['legacy:player']);
      expect(gateway.inputs, isEmpty);
    });

    testWidgets('legacy_profile_requires_existing_flow is shown, not retried '
        'into new onboarding', (tester) async {
      gateway = _Gateway(
        results: [
          const Err(
            UnifiedOnboardingFailure(
              UnifiedOnboardingError.legacyProfileRequiresExistingFlow,
            ),
          ),
        ],
      );
      await pumpWelcome(tester, data: _data(OnboardingIntention.organise));
      expect(
        find.text(
          'This account already has a profile. Please continue with the existing sign-in flow.',
        ),
        findsOneWidget,
      );
      expect(wentHome, isFalse);
      expect(wentLanding, isFalse);
    });

    testWidgets('sign-in return: no onboarding data routes out by auth state', (
      tester,
    ) async {
      gateway = _Gateway();
      await pumpWelcome(tester, signedIn: true);
      expect(wentHome, isTrue);
      expect(gateway.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      gateway = _Gateway();
      await pumpWelcome(tester, signedIn: false);
      expect(wentLanding, isTrue);
      expect(gateway.calls, isEmpty);
    });
  });
}
