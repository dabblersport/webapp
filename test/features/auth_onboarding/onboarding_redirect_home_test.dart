import 'package:dabbler/features/auth_onboarding/data/repositories/onboarding_repository.dart';
import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_state.dart';
import 'package:dabbler/features/auth_onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:dabbler/features/auth_onboarding/presentation/services/onboarding_redirect_service.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// The real repository reaches for Supabase.instance; nothing here calls it.
class _UnusedRepository implements OnboardingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CompletedController extends OnboardingController {
  _CompletedController(int profileCount)
    : super(repository: _UnusedRepository()) {
    state = OnboardingState(
      step: OnboardingStep.completed,
      existingProfileCount: profileCount,
    );
  }

  @override
  Future<void> checkResumeState() async {}
}

void main() {
  for (final int count in <int>[1, 2]) {
    testWidgets(
      'completed onboarding with existingProfileCount $count goes to home',
      (tester) async {
        final GoRouter router = GoRouter(
          initialLocation: '/start',
          routes: <RouteBase>[
            GoRoute(
              path: '/start',
              builder: (_, _) =>
                  const OnboardingCheck(child: Text('start-screen')),
            ),
            GoRoute(
              path: RoutePaths.home,
              builder: (_, _) => const Text('home-screen'),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingControllerProvider.overrideWith(
                (ref) => _CompletedController(count),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('home-screen'), findsOneWidget);
        expect(find.text('start-screen'), findsNothing);
        expect(find.textContaining('Page Not Found'), findsNothing);
        expect(find.textContaining('no routes for location'), findsNothing);
      },
    );
  }
}
