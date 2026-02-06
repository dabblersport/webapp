import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Splash screen shown on app start.
/// Hands off to router redirect logic / auth flow.
class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  bool _didAdvance = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final authState = ref.watch(simpleAuthProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    // If unauthenticated, auto-advance into the auth flow once the auth state
    // finishes loading. If authenticated, GoRouter redirect logic will
    // typically take over.
    if (!_didAdvance && !authState.isLoading && !isAuthenticated) {
      _didAdvance = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(RoutePaths.phoneInput);
      });
    }

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/logoTypo.svg',
                  height: 22,
                  fit: BoxFit.contain,
                  semanticsLabel: 'Dabbler',
                  colorFilter: ColorFilter.mode(
                    colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
